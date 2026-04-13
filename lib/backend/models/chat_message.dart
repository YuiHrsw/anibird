import 'subject.dart';

enum ChatRole { system, user, assistant }

enum ChatContentItemType { text, toolCall }

class ChatContentItem {
  const ChatContentItem.text({required this.id, required this.content})
    : type = ChatContentItemType.text,
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

  factory ChatContentItem.fromJson(Map<String, dynamic> json) {
    final type = ChatContentItemType.values.byName(
      json['type']?.toString() ?? ChatContentItemType.text.name,
    );
    return switch (type) {
      ChatContentItemType.text => ChatContentItem.text(
        id: json['id']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
      ),
      ChatContentItemType.toolCall => ChatContentItem.toolCall(
        id: json['id']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        actionInputJson: json['actionInputJson']?.toString(),
        observationJson: json['observationJson']?.toString(),
      ),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'action': action,
      'actionInputJson': actionInputJson,
      'observationJson': observationJson,
    };
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
    var finalAnswerMarkerIndex = -1;
    for (var index = contents.length - 1; index >= 0; index -= 1) {
      final item = contents[index];
      if (item.type == ChatContentItemType.toolCall &&
          item.action == 'mark_final_answer_start') {
        finalAnswerMarkerIndex = index;
        break;
      }
    }

    if (finalAnswerMarkerIndex != -1) {
      final finalTexts = contents
          .skip(finalAnswerMarkerIndex + 1)
          .where((item) => item.type == ChatContentItemType.text)
          .map((item) => item.content?.trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (finalTexts.isNotEmpty) {
        return finalTexts.join('\n\n');
      }
    }

    for (final item in contents.reversed) {
      if (item.type != ChatContentItemType.text) {
        continue;
      }
      final value = item.content?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
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

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      role: ChatRole.values.byName(
        json['role']?.toString() ?? ChatRole.assistant.name,
      ),
      contents:
          (json['contents'] as List?)
              ?.whereType<Map>()
              .map(
                (item) =>
                    ChatContentItem.fromJson(item.cast<String, dynamic>()),
              )
              .toList(growable: false) ??
          const <ChatContentItem>[],
      recommendationSubjectIds:
          (json['recommendationSubjectIds'] as List?)
              ?.map((item) => int.tryParse(item.toString()) ?? -1)
              .where((item) => item > 0)
              .toList(growable: false) ??
          const <int>[],
      isLoading: json['isLoading'] as bool? ?? false,
      isError: json['isError'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'contents': contents.map((item) => item.toJson()).toList(growable: false),
      'recommendationSubjectIds': recommendationSubjectIds,
      'isLoading': isLoading,
      'isError': isError,
    };
  }
}
