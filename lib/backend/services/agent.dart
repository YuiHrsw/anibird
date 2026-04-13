import 'dart:convert';
import 'dart:developer' as developer;

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
    required this.contents,
    required this.recommendations,
    required this.recommendationSubjectIds,
    required this.isFinal,
  });

  final List<ChatContentItem> contents;
  final List<Subject> recommendations;
  final List<int> recommendationSubjectIds;
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
    List<String>? enabledToolNames,
    bool Function()? shouldStop,
    LlmRequestController? requestController,
  }) async* {
    final availableTools = enabledToolNames == null
        ? _tools
        : {
            for (final name in enabledToolNames)
              if (_tools.containsKey(name)) name: _tools[name]!,
          };
    final messages = <LlmMessage>[
      LlmMessage(role: 'system', content: _buildSystemPrompt()),
      ...context.history.map(_historyToLlm),
      LlmMessage(role: 'user', content: text),
    ];
    final contents = <ChatContentItem>[];
    var recommendations = <Subject>[];
    var recommendationSubjectIds = <int>[];

    var turn = 0;
    while (true) {
      if ((shouldStop?.call() ?? false) ||
          (requestController?.isCancelled ?? false)) {
        yield AgentReplyUpdate(
          contents: contents,
          recommendations: recommendations,
          recommendationSubjectIds: recommendationSubjectIds,
          isFinal: true,
        );
        return;
      }

      final request = ChatRequest(
        messages: messages,
        tools: availableTools.values.map((tool) => tool.definition).toList(),
      );
      ChatResponse? response;
      var assistantText = '';
      final assistantContentId = 'assistant-turn-$turn';
      var hasAssistantTimeline = false;
      try {
        await for (final event in _llmProvider.streamChat(
          request,
          requestController: requestController,
        )) {
          if ((shouldStop?.call() ?? false) ||
              (requestController?.isCancelled ?? false)) {
            yield AgentReplyUpdate(
              contents: contents,
              recommendations: recommendations,
              recommendationSubjectIds: recommendationSubjectIds,
              isFinal: true,
            );
            return;
          }
          if (event.contentDelta.isNotEmpty) {
            assistantText = event.response.content.trim();
            if (assistantText.isNotEmpty) {
              if (!hasAssistantTimeline) {
                contents.add(
                  ChatContentItem.text(
                    id: assistantContentId,
                    content: assistantText,
                  ),
                );
                hasAssistantTimeline = true;
              } else {
                final timelineIndex = contents.lastIndexWhere(
                  (item) => item.id == assistantContentId,
                );
                if (timelineIndex != -1) {
                  contents[timelineIndex] = contents[timelineIndex].copyWith(
                    content: assistantText,
                  );
                }
              }
            }
            yield AgentReplyUpdate(
              contents: contents,
              recommendations: recommendations,
              recommendationSubjectIds: recommendationSubjectIds,
              isFinal: false,
            );
          }
          if (event.isDone) {
            response = event.response;
            assistantText = response.content.trim();
          }
        }
      } on LlmRequestCancelledException {
        yield AgentReplyUpdate(
          contents: contents,
          recommendations: recommendations,
          recommendationSubjectIds: recommendationSubjectIds,
          isFinal: true,
        );
        return;
      }
      if (response == null) {
        throw StateError('LLM 没有返回可用响应。');
      }

      if (response.toolCalls.isEmpty) {
        // if (assistantText.isEmpty) {
        //   throw StateError(
        //     '模型返回了空响应，且没有 tool_calls。当前模型或网关可能不支持 function calling，或响应格式不符合预期。',
        //   );
        // }
        messages.add(LlmMessage(role: 'assistant', content: assistantText));
        if (!hasAssistantTimeline && assistantText.isNotEmpty) {
          contents.add(
            ChatContentItem.text(
              id: assistantContentId,
              content: assistantText,
            ),
          );
        }
        yield AgentReplyUpdate(
          contents: contents,
          recommendations: recommendations,
          recommendationSubjectIds: recommendationSubjectIds,
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
        if ((shouldStop?.call() ?? false) ||
            (requestController?.isCancelled ?? false)) {
          yield AgentReplyUpdate(
            contents: contents,
            recommendations: recommendations,
            recommendationSubjectIds: recommendationSubjectIds,
            isFinal: true,
          );
          return;
        }

        final actionName = toolCall.name;
        final execution = await _executeToolCall(
          toolCall,
          tools: availableTools,
        );
        messages.add(execution.toolMessage);
        contents.add(
          ChatContentItem.toolCall(
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
        recommendationSubjectIds = _mergeRecommendationIds(
          current: recommendationSubjectIds,
          incoming: execution.recommendationSubjectIds,
        );
        yield AgentReplyUpdate(
          contents: contents,
          recommendations: recommendations,
          recommendationSubjectIds: recommendationSubjectIds,
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

  Future<_ToolExecutionResult> _executeToolCall(
    ToolCall toolCall, {
    required Map<String, AgentTool> tools,
  }) async {
    final actionName = toolCall.name;
    final tool = tools[actionName];
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
      developer.log(
        'Tool success name=$actionName input=${_prettyJson(toolCall.arguments)} '
        'observation=${formatStructuredData(result.payload, label: 'Observation')}',
        name: 'anibird.agent.tool',
      );
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
      developer.log(
        'Tool failure name=$actionName input=${_prettyJson(toolCall.arguments)} '
        'observation=${formatStructuredData(errorPayload, label: 'Observation')}',
        name: 'anibird.agent.tool',
        error: error,
      );
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

动画相关问题请优先通过 Bangumi 工具获取事实，再回答用户问题。
推荐番剧时, 除非用户要求, 不得推荐用户看过或者抛弃的番剧
最终回答使用中文 Markdown 格式。
除非用户明确要求极短回答，否则尽量给出详细清晰的回答。

请优先推荐评分较高(不能低于6分), 且用户还没看过的番剧
搜索工具和获取详细工具已经包含了用户是否看过的信息
如无必要, 不需要单独调用获取收藏工具

基于 tag 的搜索相比于基于 keyword 的名称搜索更具灵活性

Bangumi 的 api 出现超时等网络请求报错是正常的, 建议最多重试 3 次
如果想优化用户查看你的回答时的体验, 可以尝试调用 set_recommendations.
在准备开始输出最终给用户看的答案前，请先调用 mark_final_answer_start。
mark_final_answer_start 之后到消息结束的内容会被视为最终答案区。
调用工具获取信息的操作请在最终回答之前完成, 不要在最终答案区多次调用工具并输出思考流程,这会导致你的结果中出现大量多余信息.
如果你需要重新回答,请再次调用 mark_final_answer_start 以覆盖之前的无效内容
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

List<int> _mergeRecommendationIds({
  required List<int> current,
  required List<int> incoming,
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
    required this.recommendationSubjectIds,
  });

  final LlmMessage toolMessage;
  final String actionInputJson;
  final List<Subject> subjects;
  final String observationJson;
  final List<int> recommendationSubjectIds;

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
      observationJson: formatStructuredData(
        result.payload,
        label: 'Observation',
      ),
      recommendationSubjectIds: result.recommendationSubjectIds,
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
      recommendationSubjectIds: const <int>[],
    );
  }
}
