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

class AgentReply {
  const AgentReply({
    required this.text,
    required this.recommendations,
    required this.toolTraces,
  });

  final String text;
  final List<Subject> recommendations;
  final List<ToolTrace> toolTraces;
}

class AgentReplyUpdate {
  const AgentReplyUpdate({
    required this.text,
    required this.recommendations,
    required this.toolTraces,
    required this.steps,
    this.statusText,
    required this.isFinal,
  });

  final String text;
  final List<Subject> recommendations;
  final List<ToolTrace> toolTraces;
  final List<AgentStep> steps;
  final String? statusText;
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
    final reactMessages = <LlmMessage>[
      LlmMessage(role: 'system', content: _buildSystemPrompt(_tools.values)),
      ...context.history.map(_historyToLlm),
      LlmMessage(role: 'user', content: text),
    ];
    final traces = <ToolTrace>[];
    final steps = <AgentStep>[];
    var finalRecommendations = <Subject>[];
    var stepIndex = 0;

    while (!(shouldStop?.call() ?? false)) {
      yield AgentReplyUpdate(
        text: '',
        recommendations: finalRecommendations,
        toolTraces: traces,
        steps: steps,
        statusText: '正在进行第 ${stepIndex + 1} 步推理...',
        isFinal: false,
      );

      final modelText = await _completeReactStep(reactMessages);
      if (shouldStop?.call() ?? false) {
        yield AgentReplyUpdate(
          text: '',
          recommendations: finalRecommendations,
          toolTraces: traces,
          steps: steps,
          statusText: null,
          isFinal: true,
        );
        return;
      }

      final decision = _parseDecision(modelText);
      reactMessages.add(LlmMessage(role: 'assistant', content: modelText));

      if (decision.type == _DecisionType.finalAnswer) {
        steps.add(
          AgentStep(
            thought: decision.thought ?? '',
            action: 'final_answer',
            status: 'completed',
          ),
        );
        final finalText = decision.finalAnswer?.trim();
        yield AgentReplyUpdate(
          text: (finalText == null || finalText.isEmpty)
              ? '基于 Bangumi 数据检索结果整理，我已经拿到足够观察结果，但模型没有给出可用的最终回答。请手动停止后查看下方 ReAct 过程和工具记录。'
              : finalText,
          recommendations: finalRecommendations,
          toolTraces: traces,
          steps: steps,
          statusText: null,
          isFinal: true,
        );
        return;
      }

      if (decision.type == _DecisionType.invalid) {
        reactMessages.add(
          const LlmMessage(
            role: 'user',
            content:
                'Observation: 你刚才的输出无法解析。请严格只返回 JSON，并包含 thought、action、action_input 或 final_answer。',
          ),
        );
        yield AgentReplyUpdate(
          text: '',
          recommendations: finalRecommendations,
          toolTraces: traces,
          steps: steps,
          statusText: '模型输出格式不正确，正在要求其重新按 ReAct 格式响应...',
          isFinal: false,
        );
        stepIndex += 1;
        continue;
      }

      final actionName = decision.actionName;
      if (actionName == null || actionName.isEmpty) {
        reactMessages.add(
          const LlmMessage(
            role: 'user',
            content: 'Observation: action 不能为空。请选择一个可用工具，或者直接给出 final_answer。',
          ),
        );
        stepIndex += 1;
        continue;
      }

      steps.add(
        AgentStep(
          thought: decision.thought ?? '',
          action: actionName,
          actionInputJson: _prettyJson(decision.actionInput),
          status: 'started',
        ),
      );

      final tool = _tools[actionName];
      if (tool == null) {
        final errorPayload = <String, dynamic>{
          'ok': false,
          'error': 'tool_not_found',
          'message': 'Tool $actionName is not available.',
        };
        traces.add(
          ToolTrace(
            toolName: actionName,
            summary: '未找到对应工具，已将错误返回给模型。',
            inputJson: _prettyJson(decision.actionInput),
            outputJson: formatStructuredData(
              errorPayload,
              label: 'Tool error',
            ),
          ),
        );
        reactMessages.add(
          LlmMessage(
            role: 'user',
            content: 'Observation from $actionName:\n${_errorObservationText(errorPayload)}',
          ),
        );
        steps[steps.length - 1] = AgentStep(
          thought: steps.last.thought,
          action: steps.last.action,
          actionInputJson: steps.last.actionInputJson,
          observationJson: formatStructuredData(
            errorPayload,
            label: 'Observation',
          ),
          status: 'failed',
        );
        stepIndex += 1;
        continue;
      }

      yield AgentReplyUpdate(
        text: '',
        recommendations: finalRecommendations,
        toolTraces: traces,
        steps: steps,
        statusText: '正在执行 ${tool.definition.name}...',
        isFinal: false,
      );

      try {
        final result = await tool.execute(decision.actionInput);
        if (shouldStop?.call() ?? false) {
          yield AgentReplyUpdate(
            text: '',
            recommendations: finalRecommendations,
            toolTraces: traces,
            steps: steps,
            statusText: null,
            isFinal: true,
          );
          return;
        }
        traces.add(
          ToolTrace(
            toolName: result.toolName,
            summary: result.summary,
            inputJson: _prettyJson(decision.actionInput),
            outputJson: formatStructuredData(
              result.payload,
              label: 'Tool output',
            ),
          ),
        );
        if (result.toolName == 'present_recommendations') {
          finalRecommendations = result.subjects;
        }
        reactMessages.add(
          LlmMessage(
            role: 'user',
            content:
                'Observation from ${result.toolName}:\n${result.observationText}',
          ),
        );
        steps[steps.length - 1] = AgentStep(
          thought: steps.last.thought,
          action: steps.last.action,
          actionInputJson: steps.last.actionInputJson,
          observationJson: formatStructuredData(
            result.payload,
            label: 'Observation',
          ),
          status: 'completed',
        );
        yield AgentReplyUpdate(
          text: '',
          recommendations: finalRecommendations,
          toolTraces: traces,
          steps: steps,
          statusText: result.toolName == 'present_recommendations'
              ? '已更新最终推荐列表，正在生成最终回答...'
              : '已获取 ${result.toolName} 的观察结果，正在继续推理...',
          isFinal: false,
        );
      } catch (error) {
        final errorPayload = <String, dynamic>{
          'ok': false,
          'error': 'tool_execution_failed',
          'message': error.toString(),
          'tool_name': tool.definition.name,
          'input': decision.actionInput,
        };
        traces.add(
          ToolTrace(
            toolName: tool.definition.name,
            summary: '调用失败，错误已返回给模型重试。',
            inputJson: _prettyJson(decision.actionInput),
            outputJson: formatStructuredData(
              errorPayload,
              label: 'Tool error',
            ),
          ),
        );
        reactMessages.add(
          LlmMessage(
            role: 'user',
            content:
                'Observation from ${tool.definition.name}:\n${_errorObservationText(errorPayload)}\n请根据错误修正参数后继续。',
          ),
        );
        steps[steps.length - 1] = AgentStep(
          thought: steps.last.thought,
          action: steps.last.action,
          actionInputJson: steps.last.actionInputJson,
          observationJson: formatStructuredData(
            errorPayload,
            label: 'Observation',
          ),
          status: 'failed',
        );
        yield AgentReplyUpdate(
          text: '',
          recommendations: finalRecommendations,
          toolTraces: traces,
          steps: steps,
          statusText: '工具 ${tool.definition.name} 调用失败，正在让模型修正参数重试...',
          isFinal: false,
        );
      }

      stepIndex += 1;
    }

    yield AgentReplyUpdate(
      text: '',
      recommendations: finalRecommendations,
      toolTraces: traces,
      steps: steps,
      statusText: null,
      isFinal: true,
    );
  }

  Future<AgentReply> sendUserMessage(String text, ChatContext context) async {
    AgentReplyUpdate? lastUpdate;
    await for (final update in streamUserMessage(text, context)) {
      lastUpdate = update;
    }
    final fallback =
        lastUpdate ??
        const AgentReplyUpdate(
          text: '基于 Bangumi 数据检索结果整理，我暂时没有拿到足够信息。',
          recommendations: <Subject>[],
          toolTraces: <ToolTrace>[],
          steps: <AgentStep>[],
          statusText: null,
          isFinal: true,
        );
    return AgentReply(
      text: fallback.text,
      recommendations: fallback.recommendations,
      toolTraces: fallback.toolTraces,
    );
  }

  Future<String> _completeReactStep(List<LlmMessage> messages) async {
    final buffer = StringBuffer();
    await for (final event in _llmProvider.streamChat(
      ChatRequest(messages: messages),
    )) {
      if (event.contentDelta.isNotEmpty) {
        buffer.write(event.contentDelta);
      } else if (event.isDone) {
        buffer
          ..clear()
          ..write(event.response.content);
      }
    }
    return buffer.toString().trim();
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
}

enum _DecisionType { action, finalAnswer, invalid }

class _ReActDecision {
  const _ReActDecision({
    required this.type,
    this.thought,
    this.actionName,
    this.actionInput = const <String, dynamic>{},
    this.finalAnswer,
  });

  final _DecisionType type;
  final String? thought;
  final String? actionName;
  final Map<String, dynamic> actionInput;
  final String? finalAnswer;
}

_ReActDecision _parseDecision(String rawText) {
  try {
    final decoded = jsonDecode(_extractJsonObject(rawText));
    if (decoded is! Map) {
      return const _ReActDecision(type: _DecisionType.invalid);
    }
    final map = decoded.cast<String, dynamic>();
    final action = map['action']?.toString().trim();
    if (action == 'final_answer') {
      return _ReActDecision(
        type: _DecisionType.finalAnswer,
        thought: map['thought']?.toString(),
        finalAnswer: map['final_answer']?.toString(),
      );
    }
    if (action == null || action.isEmpty) {
      return const _ReActDecision(type: _DecisionType.invalid);
    }
    return _ReActDecision(
      type: _DecisionType.action,
      thought: map['thought']?.toString(),
      actionName: action,
      actionInput:
          (map['action_input'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  } catch (_) {
    return const _ReActDecision(type: _DecisionType.invalid);
  }
}

String _extractJsonObject(String rawText) {
  final trimmed = rawText.trim();
  if (trimmed.startsWith('```')) {
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      return trimmed.substring(firstBrace, lastBrace + 1);
    }
  }
  return trimmed;
}

String _buildSystemPrompt(Iterable<AgentTool> tools) {
  final toolList = tools
      .map(
        (tool) =>
            '- ${tool.definition.name}: ${tool.definition.description}\n'
            '  schema: ${jsonEncode(tool.definition.inputSchema)}',
      )
      .join('\n');

  return '''
你是 Anibird 内置的 Bangumi 动画助手，现在必须严格按照 ReAct 模式工作。

你每一步都只能返回一个 JSON 对象，不要输出任何 JSON 之外的文字。

可用动作:
$toolList

输出格式只有两种:

1. 继续行动
{
  "thought": "你对当前信息的简短判断",
  "action": "工具名",
  "action_input": {
    "参数": "值"
  }
}

2. 给出最终答案
{
  "thought": "为什么现在可以回答",
  "action": "final_answer",
  "final_answer": "基于 Bangumi 数据检索结果整理，... 最终给用户展示的 Markdown 回答"
}

规则:
1. 严格只输出 JSON。
2. 一次只做一个 action。
3. 当用户按题材、风格、圈层、标签找番时，优先使用 search_subjects_by_tags，再考虑 search_anime。
4. 对所有会返回列表的工具，主动设置合适的数量参数；一般先召回 5 到 8 条，不要一次取太多。
5. 如果你希望在回答下方展示推荐卡片，可以在 final_answer 之前调用 present_recommendations，并传入最终推荐的 subject_id 列表，顺序最好和正文推荐顺序一致。
6. 除了 present_recommendations，其它工具都只是过程，不代表最终推荐结果。
7. 搜索工具的 sort 只能使用 match、heat、rank、score；不确定时用 match。
8. 如果 Observation 显示 ok=false 或错误信息，必须根据错误修正参数后再继续。
9. 最终回答必须明确说明“基于 Bangumi 数据检索结果整理”。
10. 不要因为步数或谨慎而停止推理，除非你已经调用了必要工具并能给出 final_answer。
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
