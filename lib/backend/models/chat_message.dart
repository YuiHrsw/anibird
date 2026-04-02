import 'subject.dart';

enum ChatRole { system, user, assistant }
enum ChatTimelineItemType { assistant, toolCall }

class ChatTimelineItem {
  const ChatTimelineItem.assistant({
    required this.id,
    required this.content,
  }) : type = ChatTimelineItemType.assistant,
       action = null,
       actionInputJson = null,
       observationJson = null;

  const ChatTimelineItem.toolCall({
    required this.id,
    required this.action,
    required this.actionInputJson,
    required this.observationJson,
  }) : type = ChatTimelineItemType.toolCall,
       content = null;

  final String id;
  final ChatTimelineItemType type;
  final String? content;
  final String? action;
  final String? actionInputJson;
  final String? observationJson;

  ChatTimelineItem copyWith({
    String? id,
    String? content,
    String? action,
    String? actionInputJson,
    String? observationJson,
  }) {
    if (type == ChatTimelineItemType.assistant) {
      return ChatTimelineItem.assistant(
        id: id ?? this.id,
        content: content ?? this.content ?? '',
      );
    }
    return ChatTimelineItem.toolCall(
      id: id ?? this.id,
      action: action ?? this.action ?? '',
      actionInputJson: actionInputJson ?? this.actionInputJson,
      observationJson: observationJson ?? this.observationJson,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.timeline = const <ChatTimelineItem>[],
    this.recommendations = const <Subject>[],
    this.isLoading = false,
    this.isError = false,
  });

  final String id;
  final ChatRole role;
  final String content;
  final List<ChatTimelineItem> timeline;
  final List<Subject> recommendations;
  final bool isLoading;
  final bool isError;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    List<ChatTimelineItem>? timeline,
    List<Subject>? recommendations,
    bool? isLoading,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timeline: timeline ?? this.timeline,
      recommendations: recommendations ?? this.recommendations,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
    );
  }
}
