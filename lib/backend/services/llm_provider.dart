import 'dart:convert';

import '../models/tool.dart';

class LlmMessage {
  const LlmMessage({
    required this.role,
    required this.content,
    this.name,
    this.toolCallId,
    this.toolCalls = const <ToolCall>[],
  });

  final String role;
  final String content;
  final String? name;
  final String? toolCallId;
  final List<ToolCall> toolCalls;

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      if (content.isNotEmpty) 'content': content,
      if (name != null) 'name': name,
      if (toolCallId != null) 'tool_call_id': toolCallId,
      if (toolCalls.isNotEmpty)
        'tool_calls': toolCalls
            .map(
              (toolCall) => {
                'id': toolCall.id,
                'type': 'function',
                'function': {
                  'name': toolCall.name,
                  'arguments': jsonEncode(toolCall.arguments),
                },
              },
            )
            .toList(growable: false),
    };
  }
}

class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
}

class ChatRequest {
  const ChatRequest({
    required this.messages,
    this.tools = const <ToolDefinition>[],
  });

  final List<LlmMessage> messages;
  final List<ToolDefinition> tools;
}

class ChatResponse {
  const ChatResponse({
    required this.content,
    this.toolCalls = const <ToolCall>[],
  });

  final String content;
  final List<ToolCall> toolCalls;
}

class LlmStreamEvent {
  const LlmStreamEvent({
    required this.response,
    this.contentDelta = '',
    this.isDone = true,
  });

  final ChatResponse response;
  final String contentDelta;
  final bool isDone;
}
