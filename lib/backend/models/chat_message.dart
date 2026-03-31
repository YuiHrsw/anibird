import 'subject.dart';

enum ChatRole { system, user, assistant }

class ToolTrace {
  const ToolTrace({
    required this.toolName,
    required this.summary,
    required this.inputJson,
    required this.outputJson,
  });

  final String toolName;
  final String summary;
  final String inputJson;
  final String outputJson;
}

class AgentStep {
  const AgentStep({
    required this.thought,
    required this.action,
    this.actionInputJson,
    this.observationJson,
    required this.status,
  });

  final String thought;
  final String action;
  final String? actionInputJson;
  final String? observationJson;
  final String status;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.recommendations = const <Subject>[],
    this.toolTraces = const <ToolTrace>[],
    this.steps = const <AgentStep>[],
    this.statusText,
    this.isLoading = false,
    this.isError = false,
  });

  final String id;
  final ChatRole role;
  final String content;
  final List<Subject> recommendations;
  final List<ToolTrace> toolTraces;
  final List<AgentStep> steps;
  final String? statusText;
  final bool isLoading;
  final bool isError;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    List<Subject>? recommendations,
    List<ToolTrace>? toolTraces,
    List<AgentStep>? steps,
    String? statusText,
    bool? isLoading,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      recommendations: recommendations ?? this.recommendations,
      toolTraces: toolTraces ?? this.toolTraces,
      steps: steps ?? this.steps,
      statusText: statusText ?? this.statusText,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
    );
  }
}
