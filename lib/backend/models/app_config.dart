class AppConfig {
  const AppConfig({
    required this.llmBaseUrl,
    required this.llmApiKey,
    required this.llmModel,
    required this.bangumiUserAgent,
    required this.debugShowToolTrace,
  });

  static const defaults = AppConfig(
    llmBaseUrl: 'https://api.openai.com/v1',
    llmApiKey: '',
    llmModel: '',
    bangumiUserAgent: 'Anibird/0.1.0 (Flutter)',
    debugShowToolTrace: true,
  );

  final String llmBaseUrl;
  final String llmApiKey;
  final String llmModel;
  final String bangumiUserAgent;
  final bool debugShowToolTrace;

  AppConfig copyWith({
    String? llmBaseUrl,
    String? llmApiKey,
    String? llmModel,
    String? bangumiUserAgent,
    bool? debugShowToolTrace,
  }) {
    return AppConfig(
      llmBaseUrl: llmBaseUrl ?? this.llmBaseUrl,
      llmApiKey: llmApiKey ?? this.llmApiKey,
      llmModel: llmModel ?? this.llmModel,
      bangumiUserAgent: bangumiUserAgent ?? this.bangumiUserAgent,
      debugShowToolTrace: debugShowToolTrace ?? this.debugShowToolTrace,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'llmBaseUrl': llmBaseUrl,
      'llmApiKey': llmApiKey,
      'llmModel': llmModel,
      'bangumiUserAgent': bangumiUserAgent,
      'debugShowToolTrace': debugShowToolTrace,
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      llmBaseUrl: json['llmBaseUrl']?.toString() ?? defaults.llmBaseUrl,
      llmApiKey: json['llmApiKey']?.toString() ?? defaults.llmApiKey,
      llmModel: json['llmModel']?.toString() ?? defaults.llmModel,
      bangumiUserAgent:
          json['bangumiUserAgent']?.toString() ?? defaults.bangumiUserAgent,
      debugShowToolTrace:
          json['debugShowToolTrace'] as bool? ?? defaults.debugShowToolTrace,
    );
  }
}
