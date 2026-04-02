import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../config/file_config_repository.dart';
import '../../models/app_config.dart';
import '../../models/tool.dart';
import '../../services/llm_provider.dart';

class LlmConfigurationException implements Exception {
  const LlmConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenAICompatibleLlmProvider {
  OpenAICompatibleLlmProvider(this._configRepository, {HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final FileConfigRepository _configRepository;
  final HttpClient _httpClient;

  Stream<LlmStreamEvent> streamChat(ChatRequest request) async* {
    final config = await _configRepository.load();
    _validateConfig(config);
    final uri = _buildChatUri(config.llmBaseUrl);
    developer.log(
      'Sending LLM request to $uri with model=${config.llmModel}',
      name: 'anibird.llm',
    );
    final httpRequest = await _httpClient.postUrl(uri);
    httpRequest.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${config.llmApiKey.trim()}',
    );
    httpRequest.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );
    httpRequest.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    final requestBody = jsonEncode({
      'model': config.llmModel,
      'stream': true,
      'messages': request.messages.map((message) => message.toJson()).toList(),
      if (request.tools.isNotEmpty)
        'tools': request.tools.map(_toolToJson).toList(growable: false),
      if (request.tools.isNotEmpty) 'tool_choice': 'auto',
    });
    httpRequest.add(utf8.encode(requestBody));

    final response = await httpRequest.close().timeout(
      const Duration(seconds: 30),
    );
    if (response.statusCode >= 400) {
      final text = await response.transform(utf8.decoder).join();
      developer.log(
        'LLM response status=${response.statusCode} body=$text',
        name: 'anibird.llm',
      );
      if (request.tools.isNotEmpty &&
          (response.statusCode == 400 || response.statusCode == 422)) {
        throw LlmConfigurationException(
          '当前模型或网关不支持 function calling / tools 请求格式：$text',
        );
      }
      throw LlmConfigurationException(
        'LLM request failed (${response.statusCode}): $text',
      );
    }

    final contentBuffer = StringBuffer();
    final toolBuilders = <int, _ToolCallAccumulator>{};

    await for (final line
        in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) {
        continue;
      }
      final payload = line.substring(6).trim();
      if (payload.isEmpty) {
        continue;
      }
      if (payload == '[DONE]') {
        break;
      }

      final json = jsonDecode(payload) as Map<String, dynamic>;
      final choices = json['choices'] as List? ?? const [];
      if (choices.isEmpty) {
        continue;
      }

      final choice = (choices.first as Map).cast<String, dynamic>();
      final delta =
          (choice['delta'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final deltaText = _flattenContent(delta['content']);
      if (deltaText.isNotEmpty) {
        contentBuffer.write(deltaText);
        yield LlmStreamEvent(
          response: ChatResponse(
            content: contentBuffer.toString(),
            toolCalls: _materializeToolCalls(toolBuilders),
          ),
          contentDelta: deltaText,
          isDone: false,
        );
      }

      final deltaToolCalls =
          (delta['tool_calls'] as List?)?.whereType<Map>() ?? const <Map>[];
      for (final item in deltaToolCalls) {
        final toolDelta = item.cast<String, dynamic>();
        final index = (toolDelta['index'] as int?) ?? 0;
        final builder = toolBuilders.putIfAbsent(
          index,
          _ToolCallAccumulator.new,
        );
        builder.merge(toolDelta);
      }
    }

    final finalResponse = ChatResponse(
      content: contentBuffer.toString(),
      toolCalls: _materializeToolCalls(toolBuilders),
    );
    developer.log(
      'LLM stream completed contentLength=${finalResponse.content.length} toolCalls=${finalResponse.toolCalls.length}',
      name: 'anibird.llm',
    );
    yield LlmStreamEvent(response: finalResponse, isDone: true);
  }

  Map<String, dynamic> _toolToJson(ToolDefinition definition) {
    return {
      'type': 'function',
      'function': {
        'name': definition.name,
        'description': definition.description,
        'parameters': definition.inputSchema,
      },
    };
  }

  String _flattenContent(Object? content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      return content
          .whereType<Map>()
          .map((item) => item['text']?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .join('\n');
    }
    return '';
  }

  void _validateConfig(AppConfig config) {
    if (config.llmBaseUrl.isEmpty ||
        config.llmApiKey.isEmpty ||
        config.llmModel.isEmpty) {
      throw const LlmConfigurationException(
        '请先在“我的”页面配置 LLM base URL、API key 和 model。',
      );
    }
  }

  Uri _buildChatUri(String rawBaseUrl) {
    final normalized = rawBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      throw LlmConfigurationException(
        'LLM Base URL 无效，请填写完整地址，例如 https://api.openai.com/v1',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw LlmConfigurationException(
        'LLM Base URL 必须以 http:// 或 https:// 开头。',
      );
    }
    final baseSegments = uri.pathSegments.where(
      (segment) => segment.isNotEmpty,
    );
    return uri.replace(pathSegments: [...baseSegments, 'chat', 'completions']);
  }
}

List<ToolCall> _materializeToolCalls(Map<int, _ToolCallAccumulator> builders) {
  final entries = builders.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((entry) => entry.value.build()).toList(growable: false);
}

class _ToolCallAccumulator {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();

  void merge(Map<String, dynamic> delta) {
    id = delta['id']?.toString() ?? id;
    final function =
        (delta['function'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    name = function['name']?.toString() ?? name;
    final argumentChunk = function['arguments']?.toString() ?? '';
    if (argumentChunk.isNotEmpty) {
      arguments.write(argumentChunk);
    }
  }

  ToolCall build() {
    final rawArguments = arguments.toString().trim();
    final decoded = rawArguments.isEmpty
        ? const <String, dynamic>{}
        : (jsonDecode(rawArguments) as Map).cast<String, dynamic>();
    return ToolCall(id: id.isEmpty ? name : id, name: name, arguments: decoded);
  }
}
