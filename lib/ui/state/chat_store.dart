import 'dart:async';
import 'dart:developer' as developer;

import '../../backend/api/bangumi_repository.dart';
import '../../backend/models/chat_message.dart';
import '../../backend/models/subject.dart';
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
  ChatStore(this._agent, this._bangumiRepository) {
    _controller = StreamController<ChatViewState>.broadcast(
      onListen: () => _controller.add(_state),
    );
  }

  final Agent _agent;
  final BangumiRepository _bangumiRepository;
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
        contents: [
          ChatContentItem.text(
            id: 'user-${DateTime.now().microsecondsSinceEpoch}',
            content: trimmed,
          ),
        ],
      ),
      ChatMessage(
        id: loadingId,
        role: ChatRole.assistant,
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
          .where((item) => item.role != ChatRole.assistant || item.content.trim().isNotEmpty)
          .toList(growable: false);
      final priorHistory = history.isEmpty
          ? const <ChatMessage>[]
          : history.sublist(0, history.length - 1);

      await for (final update in _agent.streamUserMessage(
        trimmed,
        ChatContext(history: priorHistory),
        shouldStop: () => _stopRequested,
      )) {
        _replaceMessage(
          loadingId,
          ChatMessage(
            id: loadingId,
            role: ChatRole.assistant,
            contents: update.contents,
            recommendations: update.recommendations,
            recommendationSubjectIds: update.recommendationSubjectIds,
            isLoading: !update.isFinal,
          ),
        );
        unawaited(
          _resolveRecommendationsForMessage(
            loadingId,
            subjectIds: update.recommendationSubjectIds,
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
          contents: _messageById(loadingId).contents.isEmpty
              ? [
                  ChatContentItem.text(
                    id: '$loadingId-error',
                    content: '请求失败：$error',
                  ),
                ]
              : _messageById(loadingId).contents,
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

  Future<void> _resolveRecommendationsForMessage(
    String messageId, {
    required List<int> subjectIds,
  }) async {
    if (subjectIds.isEmpty) {
      return;
    }

    final initial = _messageById(messageId);
    if (!_sameRecommendationIds(initial.recommendationSubjectIds, subjectIds)) {
      return;
    }

    final subjectsById = <int, Subject>{
      for (final subject in initial.recommendations) subject.id: subject,
    };
    final missingIds = subjectIds
        .where((id) => !subjectsById.containsKey(id))
        .toList(growable: false);
    if (missingIds.isEmpty) {
      return;
    }

    for (final id in missingIds) {
      try {
        final subject = await _bangumiRepository.getSubjectDetail(id);
        final latest = _messageById(messageId);
        if (!_sameRecommendationIds(latest.recommendationSubjectIds, subjectIds)) {
          return;
        }
        subjectsById[id] = subject;
        _replaceMessage(
          messageId,
          latest.copyWith(
            recommendations: _orderedRecommendations(subjectIds, subjectsById),
          ),
        );
        _emit(_state.copyWith(messages: List<ChatMessage>.unmodifiable(_messages)));
      } catch (error, stackTrace) {
        developer.log(
          'Recommendation subject hydration failed for $id',
          name: 'anibird.chat',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  bool _sameRecommendationIds(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  List<Subject> _orderedRecommendations(
    List<int> subjectIds,
    Map<int, Subject> subjectsById,
  ) {
    return subjectIds
        .map((id) => subjectsById[id])
        .whereType<Subject>()
        .toList(growable: false);
  }
}
