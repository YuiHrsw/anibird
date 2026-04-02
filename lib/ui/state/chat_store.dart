import 'dart:async';
import 'dart:developer' as developer;

import '../../backend/models/chat_message.dart';
import '../../backend/services/agent.dart';

class ChatViewState {
  const ChatViewState({
    this.messages = const <ChatMessage>[],
    this.isGenerating = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isGenerating;
  final String? error;

  ChatViewState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? error,
    bool clearError = false,
  }) {
    return ChatViewState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ChatStore {
  ChatStore(this._agent) {
    _controller = StreamController<ChatViewState>.broadcast(
      onListen: () => _controller.add(_state),
    );
  }

  final Agent _agent;
  late final StreamController<ChatViewState> _controller;
  ChatViewState _state = const ChatViewState();
  bool _stopRequested = false;

  Stream<ChatViewState> get stream => _controller.stream;
  ChatViewState get currentState => _state;

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _state.isGenerating) {
      return;
    }

    _stopRequested = false;
    final loadingId = '${DateTime.now().microsecondsSinceEpoch}-loading';
    final nextMessages = <ChatMessage>[
      ..._state.messages,
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: ChatRole.user,
        content: trimmed,
      ),
      ChatMessage(
        id: loadingId,
        role: ChatRole.assistant,
        content: '',
        isLoading: true,
      ),
    ];
    _messages
      ..clear()
      ..addAll(nextMessages);
    _emit(
      _state.copyWith(
        messages: List<ChatMessage>.unmodifiable(_messages),
        isGenerating: true,
        clearError: true,
      ),
    );

    try {
      final history = nextMessages
          .where((item) => !item.isLoading)
          .toList(growable: false);
      final priorHistory = history.isEmpty
          ? const <ChatMessage>[]
          : history.sublist(0, history.length - 1);

      await for (final update in _agent.streamUserMessage(
        trimmed,
        ChatContext(history: priorHistory),
        shouldStop: () => _stopRequested,
      )) {
        final existing = _messageById(loadingId);
        _replaceMessage(
          loadingId,
          ChatMessage(
            id: loadingId,
            role: ChatRole.assistant,
            content: existing.content,
            timeline: update.timeline,
            recommendations: update.recommendations,
            isLoading: !update.isFinal,
          ),
        );
        _emit(_state.copyWith(messages: List<ChatMessage>.unmodifiable(_messages)));
      }
    } catch (error, stackTrace) {
      developer.log(
        'Chat request failed',
        name: 'anibird.chat',
        error: error,
        stackTrace: stackTrace,
      );
      _replaceMessage(
        loadingId,
        ChatMessage(
          id: loadingId,
          role: ChatRole.assistant,
          content: _messageById(loadingId).content.isEmpty
              ? '请求失败：$error'
              : _messageById(loadingId).content,
          isError: true,
        ),
      );
      _emit(
        _state.copyWith(
          messages: List<ChatMessage>.unmodifiable(_messages),
          error: error.toString(),
        ),
      );
    }

    if (_stopRequested) {
      final current = _messageById(loadingId);
      _replaceMessage(loadingId, current.copyWith(isLoading: false));
    }

    _emit(
      _state.copyWith(
        messages: List<ChatMessage>.unmodifiable(_messages),
        isGenerating: false,
      ),
    );
  }

  void stopGeneration() {
    _stopRequested = true;
    _emit(_state.copyWith(messages: List<ChatMessage>.unmodifiable(_messages)));
  }

  final List<ChatMessage> _messages = <ChatMessage>[];

  void _replaceMessage(String id, ChatMessage message) {
    final index = _messages.indexWhere((item) => item.id == id);
    if (index == -1) {
      _messages.add(message);
      return;
    }
    _messages[index] = message;
  }

  ChatMessage _messageById(String id) {
    final index = _messages.indexWhere((item) => item.id == id);
    if (index == -1) {
      return const ChatMessage(
        id: 'missing',
        role: ChatRole.assistant,
        content: '',
      );
    }
    return _messages[index];
  }

  void _emit(ChatViewState state) {
    _state = state;
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }

  void dispose() {
    _controller.close();
  }
}
