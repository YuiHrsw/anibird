import 'chat_message.dart';

class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const <ChatMessage>[],
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  String get preview {
    for (final message in messages.reversed) {
      final content = message.content.trim();
      if (content.isNotEmpty) {
        return content;
      }
    }
    return '还没有消息';
  }

  int get messageCount =>
      messages.where((message) => !message.isLoading).length;

  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '新对话',
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      messages:
          (json['messages'] as List?)
              ?.whereType<Map>()
              .map((item) => ChatMessage.fromJson(item.cast<String, dynamic>()))
              .toList(growable: false) ??
          const <ChatMessage>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages
          .map((message) => message.toJson())
          .toList(growable: false),
    };
  }
}

DateTime _parseDateTime(Object? value) {
  final raw = value?.toString() ?? '';
  return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
}
