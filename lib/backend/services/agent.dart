import 'dart:convert';

import '../api/llm/openai_compatible_llm_provider.dart';
import '../models/chat_message.dart';
import '../models/subject.dart';
import '../models/tool.dart';
import 'llm_provider.dart';

class ChatContext {
  const ChatContext({this.history = const <ChatMessage>[]});

  final List<ChatMessage> history;
}

class AgentReplyUpdate {
  const AgentReplyUpdate({
    required this.timeline,
    required this.recommendations,
    required this.isFinal,
  });

  final List<ChatTimelineItem> timeline;
  final List<Subject> recommendations;
  final bool isFinal;
}

class Agent {
  Agent({
    required OpenAICompatibleLlmProvider llmProvider,
    required List<AgentTool> tools,
  }) : _llmProvider = llmProvider,
       _tools = {for (final tool in tools) tool.definition.name: tool};

  final OpenAICompatibleLlmProvider _llmProvider;
  final Map<String, AgentTool> _tools;

  Stream<AgentReplyUpdate> streamUserMessage(
    String text,
    ChatContext context, {
    bool Function()? shouldStop,
  }) async* {
    final messages = <LlmMessage>[
      LlmMessage(role: 'system', content: _buildSystemPrompt()),
      ...context.history.map(_historyToLlm),
      LlmMessage(role: 'user', content: text),
    ];
    final timeline = <ChatTimelineItem>[];
    var recommendations = <Subject>[];

    var turn = 0;
    while (true) {
      if (shouldStop?.call() ?? false) {
        yield AgentReplyUpdate(
          timeline: timeline,
          recommendations: recommendations,
          isFinal: true,
        );
        return;
      }

      final request = ChatRequest(
        messages: messages,
        tools: _tools.values.map((tool) => tool.definition).toList(),
      );
      ChatResponse? response;
      var assistantText = '';
      final assistantTimelineId = 'assistant-turn-$turn';
      var hasAssistantTimeline = false;
      await for (final event in _llmProvider.streamChat(request)) {
        if (event.contentDelta.isNotEmpty) {
          assistantText = event.response.content.trim();
          if (assistantText.isNotEmpty) {
            if (!hasAssistantTimeline) {
              timeline.add(
                ChatTimelineItem.assistant(
                  id: assistantTimelineId,
                  content: assistantText,
                ),
              );
              hasAssistantTimeline = true;
            } else {
              final timelineIndex = timeline.lastIndexWhere(
                (item) => item.id == assistantTimelineId,
              );
              if (timelineIndex != -1) {
                timeline[timelineIndex] = timeline[timelineIndex].copyWith(
                  content: assistantText,
                );
              }
            }
          }
          yield AgentReplyUpdate(
            timeline: timeline,
            recommendations: recommendations,
            isFinal: false,
          );
        }
        if (event.isDone) {
          response = event.response;
          assistantText = response.content.trim();
        }
      }
      if (response == null) {
        throw StateError('LLM 没有返回可用响应。');
      }

      if (response.toolCalls.isEmpty) {
        if (assistantText.isEmpty) {
          throw StateError(
            '模型返回了空响应，且没有 tool_calls。当前模型或网关可能不支持 function calling，或响应格式不符合预期。',
          );
        }
        messages.add(LlmMessage(role: 'assistant', content: assistantText));
        if (!hasAssistantTimeline && assistantText.isNotEmpty) {
          timeline.add(
            ChatTimelineItem.assistant(
              id: assistantTimelineId,
              content: assistantText,
            ),
          );
        }
        yield AgentReplyUpdate(
          timeline: timeline,
          recommendations: recommendations,
          isFinal: true,
        );
        return;
      }

      messages.add(
        LlmMessage(
          role: 'assistant',
          content: response.content,
          toolCalls: response.toolCalls,
        ),
      );

      for (final toolCall in response.toolCalls) {
        if (shouldStop?.call() ?? false) {
          yield AgentReplyUpdate(
            timeline: timeline,
            recommendations: recommendations,
            isFinal: true,
          );
          return;
        }

        final actionName = toolCall.name;
        final execution = await _executeToolCall(toolCall);
        messages.add(execution.toolMessage);
        timeline.add(
          ChatTimelineItem.toolCall(
            id: toolCall.id,
            action: actionName,
            actionInputJson: execution.actionInputJson,
            observationJson: execution.observationJson,
          ),
        );
        recommendations = _mergeRecommendations(
          current: recommendations,
          incoming: execution.subjects,
        );
        yield AgentReplyUpdate(
          timeline: timeline,
          recommendations: recommendations,
          isFinal: false,
        );
      }

      turn += 1;
    }
  }

  LlmMessage _historyToLlm(ChatMessage message) {
    return LlmMessage(
      role: switch (message.role) {
        ChatRole.system => 'system',
        ChatRole.user => 'user',
        ChatRole.assistant => 'assistant',
      },
      content: message.content,
    );
  }

  Future<_ToolExecutionResult> _executeToolCall(ToolCall toolCall) async {
    final actionName = toolCall.name;
    final tool = _tools[actionName];
    if (tool == null) {
      final errorPayload = <String, dynamic>{
        'ok': false,
        'error': 'tool_not_found',
        'message': 'Tool $actionName is not available.',
      };
      return _ToolExecutionResult.failure(
        toolName: actionName,
        toolCallId: toolCall.id,
        input: toolCall.arguments,
        payload: errorPayload,
        summary: '未找到对应工具。',
      );
    }

    try {
      final result = await tool.execute(toolCall.arguments);
      return _ToolExecutionResult.success(
        toolCallId: toolCall.id,
        input: toolCall.arguments,
        result: result,
      );
    } catch (error) {
      final errorPayload = <String, dynamic>{
        'ok': false,
        'error': 'tool_execution_failed',
        'message': error.toString(),
        'tool_name': actionName,
        'input': toolCall.arguments,
      };
      return _ToolExecutionResult.failure(
        toolName: actionName,
        toolCallId: toolCall.id,
        input: toolCall.arguments,
        payload: errorPayload,
        summary: '工具调用失败。',
      );
    }
  }
}

String _buildSystemPrompt() {
  return '''
你是 Anibird 内置的 Bangumi 动画助手。

请优先通过 Bangumi 工具获取事实，再回答用户问题。
如果你希望在回答下方展示推荐卡片，可以调用 present_recommendations，并按展示顺序传入 subject_id。
如果要调用 present_recommendations，请在给出最终回答之前提前调用，这样用户才能正常看到你输出的结果。
搜索工具的 sort 只能使用 match、heat、rank、score；不确定时优先用 match。
如果工具结果显示 ok=false 或错误信息，请根据已有信息自行判断是否继续调用工具、调整参数，或直接回答。
最终回答使用中文 Markdown，并明确说明“基于 Bangumi 数据检索结果整理”。
除非用户明确要求极短回答，否则尽量给出详细清晰的回答。
''';
}

String _errorObservationText(Map<String, dynamic> value) {
  final lines = <String>[
    'ok=false',
    'error=${value['error']}',
    'message=${value['message']}',
  ];
  final toolName = value['tool_name']?.toString();
  if (toolName != null && toolName.isNotEmpty) {
    lines.add('tool=$toolName');
  }
  return lines.join('\n');
}

String _prettyJson(Map<String, dynamic> value) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(value);
}

List<Subject> _mergeRecommendations({
  required List<Subject> current,
  required List<Subject> incoming,
}) {
  if (incoming.isEmpty) {
    return current;
  }
  return incoming;
}

class _ToolExecutionResult {
  const _ToolExecutionResult({
    required this.toolMessage,
    required this.actionInputJson,
    required this.subjects,
    required this.observationJson,
  });

  final LlmMessage toolMessage;
  final String actionInputJson;
  final List<Subject> subjects;
  final String observationJson;

  factory _ToolExecutionResult.success({
    required String toolCallId,
    required Map<String, dynamic> input,
    required ToolResult result,
  }) {
    return _ToolExecutionResult(
      toolMessage: LlmMessage(
        role: 'tool',
        name: result.toolName,
        toolCallId: toolCallId,
        content: result.observationText,
      ),
      actionInputJson: _prettyJson(input),
      subjects: result.subjects,
      observationJson: formatStructuredData(result.payload, label: 'Observation'),
    );
  }

  factory _ToolExecutionResult.failure({
    required String toolName,
    required String toolCallId,
    required Map<String, dynamic> input,
    required Map<String, dynamic> payload,
    required String summary,
  }) {
    return _ToolExecutionResult(
      toolMessage: LlmMessage(
        role: 'tool',
        name: toolName,
        toolCallId: toolCallId,
        content: _errorObservationText(payload),
      ),
      actionInputJson: _prettyJson(input),
      subjects: const <Subject>[],
      observationJson: formatStructuredData(payload, label: 'Observation'),
    );
  }
}
