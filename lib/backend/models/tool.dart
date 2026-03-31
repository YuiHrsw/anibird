import 'dart:convert';

import 'subject.dart';

class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.requiresConfirmation = false,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final bool requiresConfirmation;
}

class ToolResult {
  const ToolResult({
    required this.toolName,
    required this.summary,
    required this.payload,
    required this.observationText,
    this.subjects = const <Subject>[],
  });

  final String toolName;
  final String summary;
  final Map<String, dynamic> payload;
  final String observationText;
  final List<Subject> subjects;

  String get jsonContent => jsonEncode(payload);
}

String formatStructuredData(
  Object? value, {
  String? label,
}) {
  final lines = <String>[];
  if (label != null && label.isNotEmpty) {
    lines.add(label);
  }
  _appendStructuredLines(lines, value, indent: 0, key: null);
  return lines.join('\n');
}

void _appendStructuredLines(
  List<String> lines,
  Object? value, {
  required int indent,
  required String? key,
}) {
  final indentText = '  ' * indent;

  if (value is Map<String, dynamic>) {
    if (value.isEmpty) {
      final prefix = key == null ? '' : '$key: ';
      lines.add('$indentText$prefix{}');
      return;
    }
    if (key != null) {
      lines.add('$indentText$key:');
    }
    for (final entry in value.entries) {
      _appendStructuredLines(
        lines,
        entry.value,
        indent: key == null ? indent : indent + 1,
        key: entry.key,
      );
    }
    return;
  }

  if (value is List) {
    if (value.isEmpty) {
      final prefix = key == null ? '' : '$key: ';
      lines.add('$indentText$prefix[]');
      return;
    }
    if (key != null) {
      lines.add('$indentText$key:');
    }
    for (var index = 0; index < value.length; index += 1) {
      final item = value[index];
      if (item is Map<String, dynamic> || item is List) {
        lines.add('${'  ' * (key == null ? indent : indent + 1)}-');
        _appendStructuredLines(
          lines,
          item,
          indent: (key == null ? indent : indent + 1) + 1,
          key: null,
        );
      } else {
        lines.add(
          '${'  ' * (key == null ? indent : indent + 1)}- ${_formatStructuredScalar(item)}',
        );
      }
    }
    return;
  }

  final prefix = key == null ? '' : '$key: ';
  lines.add('$indentText$prefix${_formatStructuredScalar(value)}');
}

String _formatStructuredScalar(Object? value) {
  if (value == null) {
    return 'null';
  }
  return value.toString().replaceAll('\n', r'\n');
}

abstract class AgentTool {
  ToolDefinition get definition;

  Future<ToolResult> execute(Map<String, dynamic> input);
}
