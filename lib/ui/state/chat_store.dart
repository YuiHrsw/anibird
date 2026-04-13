import 'dart:async';
import 'dart:developer' as developer;

import '../../backend/api/bangumi/bangumi_repository.dart';
import '../../backend/api/chat/file_chat_session_repository.dart';
import '../../backend/models/chat_message.dart';
import '../../backend/models/chat_session.dart';
import '../../backend/models/subject.dart';
import '../../backend/services/agent.dart';
import '../../backend/services/llm_provider.dart';
import 'settings_store.dart';

class ChatViewState {
  const ChatViewState({
    this.sessions = const <ChatSession>[],
    this.currentSessionId,
    this.generatingSessionIds = const <String>{},
    this.isLoaded = false,
    this.error,
  });

  final List<ChatSession> sessions;
  final String? currentSessionId;
  final Set<String> generatingSessionIds;
  final bool isLoaded;
  final String? error;

  ChatSession? get currentSession {
    for (final session in sessions) {
      if (session.id == currentSessionId) {
        return session;
      }
    }
    return sessions.isEmpty ? null : sessions.first;
  }

  List<ChatMessage> get messages =>
      currentSession?.messages ?? const <ChatMessage>[];

  bool get isGenerating => isSessionGenerating(currentSessionId);

  bool isSessionGenerating(String? sessionId) {
    if (sessionId == null) {
      return false;
    }
    return generatingSessionIds.contains(sessionId);
  }

  ChatViewState copyWith({
    List<ChatSession>? sessions,
    String? currentSessionId,
    Set<String>? generatingSessionIds,
    bool? isLoaded,
    String? error,
    bool clearError = false,
  }) {
    return ChatViewState(
      sessions: sessions ?? this.sessions,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      generatingSessionIds: generatingSessionIds ?? this.generatingSessionIds,
      isLoaded: isLoaded ?? this.isLoaded,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ChatStore {
  ChatStore(
    this._agent,
    this._bangumiRepository,
    this._chatSessionRepository,
    this._settingsStore,
  ) {
    _controller = StreamController<ChatViewState>.broadcast(
      onListen: () => _controller.add(_state),
    );
  }

  final Agent _agent;
  final BangumiRepository _bangumiRepository;
  final FileChatSessionRepository _chatSessionRepository;
  final SettingsStore _settingsStore;
  late final StreamController<ChatViewState> _controller;

  ChatViewState _state = const ChatViewState();
  bool _isLoaded = false;
  List<ChatSession> _sessions = <ChatSession>[];
  final Set<String> _generatingSessionIds = <String>{};
  final Set<String> _stopRequestedSessionIds = <String>{};
  final Map<String, LlmRequestController> _requestControllersBySessionId =
      <String, LlmRequestController>{};

  Stream<ChatViewState> get stream => _controller.stream;
  ChatViewState get currentState => _state;

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    try {
      final sessions = await _chatSessionRepository.loadAll();
      if (sessions.isEmpty) {
        final initial = _createEmptySession();
        _sessions = [initial];
        await _chatSessionRepository.save(initial);
      } else {
        _sessions = sessions;
      }
      _isLoaded = true;
      _emit(
        _state.copyWith(
          sessions: List<ChatSession>.unmodifiable(_sessions),
          currentSessionId: _sessions.first.id,
          isLoaded: true,
          clearError: true,
        ),
      );
      _hydrateVisibleRecommendations();
    } catch (error) {
      _isLoaded = true;
      _emit(_state.copyWith(isLoaded: true, error: error.toString()));
    }
  }

  Future<void> createSession() async {
    final session = _createEmptySession();
    _sessions = [session, ..._sessions];
    _emit(
      _state.copyWith(
        sessions: List<ChatSession>.unmodifiable(_sessions),
        currentSessionId: session.id,
        generatingSessionIds: Set<String>.unmodifiable(_generatingSessionIds),
        clearError: true,
      ),
    );
    await _chatSessionRepository.save(session);
  }

  Future<void> renameSession(String sessionId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final session = _sessionById(sessionId);
    if (session == null || session.title == trimmed) {
      return;
    }
    final renamed = session.copyWith(title: trimmed, updatedAt: DateTime.now());
    _upsertSession(renamed);
    _emitCurrentState();
    await _persistSession(renamed);
  }

  Future<void> deleteSession(String sessionId) async {
    if (_generatingSessionIds.contains(sessionId)) {
      return;
    }

    final exists = _sessions.any((session) => session.id == sessionId);
    if (!exists) {
      return;
    }

    _sessions = _sessions
        .where((session) => session.id != sessionId)
        .toList(growable: false);
    _stopRequestedSessionIds.remove(sessionId);
    _generatingSessionIds.remove(sessionId);
    await _chatSessionRepository.delete(sessionId);

    if (_sessions.isEmpty) {
      final session = _createEmptySession();
      _sessions = [session];
      await _chatSessionRepository.save(session);
    }

    final nextCurrentSessionId = _state.currentSessionId == sessionId
        ? _sessions.first.id
        : _state.currentSessionId;
    _emit(
      _state.copyWith(
        sessions: List<ChatSession>.unmodifiable(_sessions),
        currentSessionId: nextCurrentSessionId,
        generatingSessionIds: Set<String>.unmodifiable(_generatingSessionIds),
        clearError: true,
      ),
    );
    _hydrateVisibleRecommendations();
  }

  void selectSession(String sessionId) {
    if (sessionId == _state.currentSessionId) {
      return;
    }
    _emit(
      _state.copyWith(
        sessions: List<ChatSession>.unmodifiable(_sessions),
        currentSessionId: sessionId,
        generatingSessionIds: Set<String>.unmodifiable(_generatingSessionIds),
        clearError: true,
      ),
    );
    _hydrateVisibleRecommendations();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    final currentSessionId = _state.currentSessionId;
    if (trimmed.isEmpty || _state.isSessionGenerating(currentSessionId)) {
      return;
    }

    final session = _state.currentSession ?? _createEmptySession();
    if (!_sessions.any((item) => item.id == session.id)) {
      _sessions = [session, ..._sessions];
    }

    _stopRequestedSessionIds.remove(session.id);
    _generatingSessionIds.add(session.id);
    final requestController = LlmRequestController();
    _requestControllersBySessionId[session.id] = requestController;
    final now = DateTime.now();
    final userMessage = ChatMessage(
      id: now.microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      contents: [
        ChatContentItem.text(
          id: 'user-${now.microsecondsSinceEpoch}',
          content: trimmed,
        ),
      ],
    );
    final loadingId = '${now.microsecondsSinceEpoch}-loading';
    final loadingMessage = ChatMessage(
      id: loadingId,
      role: ChatRole.assistant,
      isLoading: true,
    );
    final nextSession = session.copyWith(
      title: _resolveSessionTitle(session, trimmed),
      updatedAt: now,
      messages: [...session.messages, userMessage, loadingMessage],
    );
    _upsertSession(nextSession);
    _emit(
      _state.copyWith(
        sessions: List<ChatSession>.unmodifiable(_sessions),
        currentSessionId: nextSession.id,
        generatingSessionIds: Set<String>.unmodifiable(_generatingSessionIds),
        clearError: true,
      ),
    );
    await _persistSession(nextSession);

    try {
      final history = nextSession.messages
          .where((item) => !item.isLoading)
          .where(
            (item) =>
                item.role != ChatRole.assistant ||
                item.content.trim().isNotEmpty,
          )
          .toList(growable: false);
      final priorHistory = history.isEmpty
          ? const <ChatMessage>[]
          : history.sublist(0, history.length - 1);

      await for (final update in _agent.streamUserMessage(
        trimmed,
        ChatContext(history: priorHistory),
        enabledToolNames: _settingsStore.value.config.enabledAgentToolNames,
        shouldStop: () => _stopRequestedSessionIds.contains(nextSession.id),
        requestController: requestController,
      )) {
        final liveSession = _sessionById(nextSession.id);
        if (liveSession == null) {
          return;
        }
        _upsertSession(
          _replaceMessage(
            liveSession,
            loadingId,
            ChatMessage(
              id: loadingId,
              role: ChatRole.assistant,
              contents: update.contents,
              recommendations: update.recommendations,
              recommendationSubjectIds: update.recommendationSubjectIds,
              isLoading: !update.isFinal,
            ),
            updatedAt: liveSession.updatedAt,
          ),
        );
        _emit(
          _state.copyWith(
            sessions: List<ChatSession>.unmodifiable(_sessions),
            generatingSessionIds: Set<String>.unmodifiable(
              _generatingSessionIds,
            ),
          ),
        );
        unawaited(
          _resolveRecommendationsForMessage(
            nextSession.id,
            loadingId,
            subjectIds: update.recommendationSubjectIds,
          ),
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Chat request failed',
        name: 'anibird.chat',
        error: error,
        stackTrace: stackTrace,
      );
      final liveSession = _sessionById(nextSession.id);
      if (liveSession != null) {
        final current = _messageById(liveSession, loadingId);
        _upsertSession(
          _replaceMessage(
            liveSession,
            loadingId,
            ChatMessage(
              id: loadingId,
              role: ChatRole.assistant,
              contents: current.contents.isEmpty
                  ? [
                      ChatContentItem.text(
                        id: '$loadingId-error',
                        content: '请求失败：$error',
                      ),
                    ]
                  : current.contents,
              isError: true,
            ),
            updatedAt: DateTime.now(),
          ),
        );
        _emit(
          _state.copyWith(
            sessions: List<ChatSession>.unmodifiable(_sessions),
            generatingSessionIds: Set<String>.unmodifiable(
              _generatingSessionIds,
            ),
            error: error.toString(),
          ),
        );
      }
    }

    final resolvedSession = _sessionById(nextSession.id);
    if (resolvedSession == null) {
      return;
    }

    final wasStopped = _stopRequestedSessionIds.contains(nextSession.id);
    _generatingSessionIds.remove(nextSession.id);
    _stopRequestedSessionIds.remove(nextSession.id);
    _requestControllersBySessionId.remove(nextSession.id);

    if (wasStopped) {
      final withoutLoading = resolvedSession.copyWith(
        messages: resolvedSession.messages
            .where((message) => message.id != loadingId)
            .toList(growable: false),
      );
      _upsertSession(withoutLoading);
      _emit(
        _state.copyWith(
          sessions: List<ChatSession>.unmodifiable(_sessions),
          generatingSessionIds: Set<String>.unmodifiable(_generatingSessionIds),
        ),
      );
      await _persistSession(withoutLoading);
      return;
    }

    final finalizedSession = _sessionById(nextSession.id);
    if (finalizedSession != null) {
      _emit(
        _state.copyWith(
          sessions: List<ChatSession>.unmodifiable(_sessions),
          generatingSessionIds: Set<String>.unmodifiable(_generatingSessionIds),
        ),
      );
      await _persistSession(finalizedSession);
    }
  }

  void stopGeneration() {
    final sessionId = _state.currentSessionId;
    if (sessionId == null) {
      return;
    }
    _stopRequestedSessionIds.add(sessionId);
    _requestControllersBySessionId[sessionId]?.cancel();
    _emit(
      _state.copyWith(
        sessions: List<ChatSession>.unmodifiable(_sessions),
        generatingSessionIds: Set<String>.unmodifiable(_generatingSessionIds),
      ),
    );
  }

  void dispose() {
    _controller.close();
  }

  Future<void> _resolveRecommendationsForMessage(
    String sessionId,
    String messageId, {
    required List<int> subjectIds,
  }) async {
    if (subjectIds.isEmpty) {
      return;
    }

    final initial = _messageById(_sessionById(sessionId), messageId);
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
        final latestSession = _sessionById(sessionId);
        final latest = _messageById(latestSession, messageId);
        if (!_sameRecommendationIds(
          latest.recommendationSubjectIds,
          subjectIds,
        )) {
          return;
        }
        subjectsById[id] = subject;
        if (latestSession == null) {
          return;
        }
        _upsertSession(
          _replaceMessage(
            latestSession,
            messageId,
            latest.copyWith(
              recommendations: _orderedRecommendations(
                subjectIds,
                subjectsById,
              ),
            ),
            updatedAt: latestSession.updatedAt,
          ),
        );
        _emit(
          _state.copyWith(
            sessions: List<ChatSession>.unmodifiable(_sessions),
            generatingSessionIds: Set<String>.unmodifiable(
              _generatingSessionIds,
            ),
          ),
        );
        await _persistSession(_sessionById(sessionId) ?? latestSession);
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

  void _hydrateVisibleRecommendations() {
    final session = _state.currentSession;
    if (session == null) {
      return;
    }
    for (final message in session.messages) {
      if (message.recommendationSubjectIds.isEmpty ||
          message.recommendations.isNotEmpty) {
        continue;
      }
      unawaited(
        _resolveRecommendationsForMessage(
          session.id,
          message.id,
          subjectIds: message.recommendationSubjectIds,
        ),
      );
    }
  }

  Future<void> _persistSession(ChatSession session) {
    final persisted = session.copyWith(
      messages: session.messages
          .where((message) => !message.isLoading)
          .map(_compactMessageForPersistence)
          .toList(growable: false),
    );
    return _chatSessionRepository.save(persisted);
  }

  ChatMessage _compactMessageForPersistence(ChatMessage message) {
    final compactContents = switch (message.role) {
      ChatRole.assistant => _compactAssistantContents(message),
      _ => message.contents
          .where((item) => item.type == ChatContentItemType.text)
          .toList(growable: false),
    };
    return message.copyWith(
      contents: compactContents,
      recommendations: const <Subject>[],
    );
  }

  List<ChatContentItem> _compactAssistantContents(ChatMessage message) {
    return message.contents
        .where(
          (item) =>
              (item.type == ChatContentItemType.text &&
                  (item.content?.trim().isNotEmpty ?? false)) ||
              (item.type == ChatContentItemType.toolCall &&
                  (item.action?.trim().isNotEmpty ?? false)),
        )
        .map((item) {
          if (item.type == ChatContentItemType.text) {
            return ChatContentItem.text(
              id: item.id,
              content: item.content?.trim() ?? '',
            );
          }
          return ChatContentItem.toolCall(
            id: item.id,
            action: item.action?.trim() ?? '',
            actionInputJson: null,
            observationJson: null,
          );
        })
        .toList(growable: false);
  }

  void _upsertSession(ChatSession session) {
    final current = _sessions
        .where((item) => item.id != session.id)
        .toList(growable: false);
    _sessions = [session, ...current]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  ChatSession? _sessionById(String id) {
    for (final session in _sessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  ChatSession _replaceMessage(
    ChatSession session,
    String messageId,
    ChatMessage message, {
    required DateTime updatedAt,
  }) {
    final messages = [...session.messages];
    final index = messages.indexWhere((item) => item.id == messageId);
    if (index == -1) {
      messages.add(message);
    } else {
      messages[index] = message;
    }
    return session.copyWith(
      updatedAt: updatedAt,
      messages: List<ChatMessage>.unmodifiable(messages),
    );
  }

  ChatMessage _messageById(ChatSession? session, String id) {
    if (session == null) {
      return const ChatMessage(id: 'missing', role: ChatRole.assistant);
    }
    for (final message in session.messages) {
      if (message.id == id) {
        return message;
      }
    }
    return const ChatMessage(id: 'missing', role: ChatRole.assistant);
  }

  String _resolveSessionTitle(ChatSession session, String text) {
    if (session.title.trim().isNotEmpty && session.title != '新对话') {
      return session.title;
    }
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.isEmpty) {
      return '新对话';
    }
    return normalized.length <= 24
        ? normalized
        : '${normalized.substring(0, 24)}...';
  }

  ChatSession _createEmptySession() {
    final now = DateTime.now();
    return ChatSession(
      id: now.microsecondsSinceEpoch.toString(),
      title: '新对话',
      createdAt: now,
      updatedAt: now,
    );
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

  void _emit(ChatViewState state) {
    _state = state;
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }

  void _emitCurrentState() {
    _emit(
      _state.copyWith(
        sessions: List<ChatSession>.unmodifiable(_sessions),
        generatingSessionIds: Set<String>.unmodifiable(_generatingSessionIds),
        clearError: true,
      ),
    );
  }
}
