import 'agent_tool_config.dart';

class AppConfig {
  const AppConfig({
    required this.llmBaseUrl,
    required this.llmApiKey,
    required this.llmModel,
    required this.enabledAgentToolNames,
    required this.bangumiAccessToken,
    required this.bangumiRefreshToken,
    required this.bangumiAccessTokenExpiresAt,
  });

  static const defaults = AppConfig(
    llmBaseUrl: 'https://api.openai.com/v1',
    llmApiKey: '',
    llmModel: '',
    enabledAgentToolNames: defaultEnabledAgentToolNames,
    bangumiAccessToken: '',
    bangumiRefreshToken: '',
    bangumiAccessTokenExpiresAt: 0,
  );

  final String llmBaseUrl;
  final String llmApiKey;
  final String llmModel;
  final List<String> enabledAgentToolNames;
  final String bangumiAccessToken;
  final String bangumiRefreshToken;
  final int bangumiAccessTokenExpiresAt;

  AppConfig copyWith({
    String? llmBaseUrl,
    String? llmApiKey,
    String? llmModel,
    List<String>? enabledAgentToolNames,
    String? bangumiAccessToken,
    String? bangumiRefreshToken,
    int? bangumiAccessTokenExpiresAt,
  }) {
    return AppConfig(
      llmBaseUrl: llmBaseUrl ?? this.llmBaseUrl,
      llmApiKey: llmApiKey ?? this.llmApiKey,
      llmModel: llmModel ?? this.llmModel,
      enabledAgentToolNames:
          enabledAgentToolNames ?? this.enabledAgentToolNames,
      bangumiAccessToken: bangumiAccessToken ?? this.bangumiAccessToken,
      bangumiRefreshToken: bangumiRefreshToken ?? this.bangumiRefreshToken,
      bangumiAccessTokenExpiresAt:
          bangumiAccessTokenExpiresAt ?? this.bangumiAccessTokenExpiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'llmBaseUrl': llmBaseUrl,
      'llmApiKey': llmApiKey,
      'llmModel': llmModel,
      'enabledAgentToolNames': enabledAgentToolNames,
      'bangumiAccessToken': bangumiAccessToken,
      'bangumiRefreshToken': bangumiRefreshToken,
      'bangumiAccessTokenExpiresAt': bangumiAccessTokenExpiresAt,
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      llmBaseUrl: json['llmBaseUrl']?.toString() ?? defaults.llmBaseUrl,
      llmApiKey: json['llmApiKey']?.toString() ?? defaults.llmApiKey,
      llmModel: json['llmModel']?.toString() ?? defaults.llmModel,
      enabledAgentToolNames: _asStringList(
        json['enabledAgentToolNames'],
        defaults.enabledAgentToolNames,
      ),
      bangumiAccessToken:
          json['bangumiAccessToken']?.toString() ?? defaults.bangumiAccessToken,
      bangumiRefreshToken:
          json['bangumiRefreshToken']?.toString() ??
          defaults.bangumiRefreshToken,
      bangumiAccessTokenExpiresAt: _asInt(
        json['bangumiAccessTokenExpiresAt'],
        defaults.bangumiAccessTokenExpiresAt,
      ),
    );
  }
}

List<String> _asStringList(Object? value, List<String> fallback) {
  if (value is! List) {
    return fallback;
  }
  return value
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .map(
        (item) =>
            item == 'present_recommendations' ? 'set_recommendations' : item,
      )
      .toList(growable: false);
}

int _asInt(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
