import 'subject.dart';

enum ChatRole { system, user, assistant }
enum ChatContentItemType { text, toolCall }

class ChatContentItem {
  const ChatContentItem.text({
    required this.id,
    required this.content,
  }) : type = ChatContentItemType.text,
       action = null,
       actionInputJson = null,
       observationJson = null;

  const ChatContentItem.toolCall({
    required this.id,
    required this.action,
    required this.actionInputJson,
    required this.observationJson,
  }) : type = ChatContentItemType.toolCall,
       content = null;

  final String id;
  final ChatContentItemType type;
  final String? content;
  final String? action;
  final String? actionInputJson;
  final String? observationJson;

  ChatContentItem copyWith({
    String? id,
    String? content,
    String? action,
    String? actionInputJson,
    String? observationJson,
  }) {
    if (type == ChatContentItemType.text) {
      return ChatContentItem.text(
        id: id ?? this.id,
        content: content ?? this.content ?? '',
      );
    }
    return ChatContentItem.toolCall(
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
    this.contents = const <ChatContentItem>[],
    this.recommendations = const <Subject>[],
    this.recommendationSubjectIds = const <int>[],
    this.isLoading = false,
    this.isError = false,
  });

  final String id;
  final ChatRole role;
  final List<ChatContentItem> contents;
  final List<Subject> recommendations;
  final List<int> recommendationSubjectIds;
  final bool isLoading;
  final bool isError;

  String get content {
    for (final item in contents.reversed) {
      if (item.type == ChatContentItemType.text) {
        final value = item.content?.trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return '';
  }

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    List<ChatContentItem>? contents,
    List<Subject>? recommendations,
    List<int>? recommendationSubjectIds,
    bool? isLoading,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      contents: contents ?? this.contents,
      recommendations: recommendations ?? this.recommendations,
      recommendationSubjectIds:
          recommendationSubjectIds ?? this.recommendationSubjectIds,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
    );
  }
}
