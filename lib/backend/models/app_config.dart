class AppConfig {
  const AppConfig({
    required this.llmBaseUrl,
    required this.llmApiKey,
    required this.llmModel,
    required this.bangumiUserAgent,
    required this.bangumiPrivateApiBaseUrl,
    required this.bangumiOauthClientId,
    required this.bangumiOauthClientSecret,
    required this.bangumiOauthRedirectUri,
    required this.bangumiAccessToken,
    required this.bangumiRefreshToken,
    required this.bangumiAccessTokenExpiresAt,
  });

  static const defaults = AppConfig(
    llmBaseUrl: 'https://api.openai.com/v1',
    llmApiKey: '',
    llmModel: '',
    bangumiUserAgent: 'Anibird/0.1.0 (Flutter)',
    bangumiPrivateApiBaseUrl: 'https://next.bgm.tv/p1',
    bangumiOauthClientId: '',
    bangumiOauthClientSecret: '',
    bangumiOauthRedirectUri: 'anibird://oauth/callback',
    bangumiAccessToken: '',
    bangumiRefreshToken: '',
    bangumiAccessTokenExpiresAt: 0,
  );

  final String llmBaseUrl;
  final String llmApiKey;
  final String llmModel;
  final String bangumiUserAgent;
  final String bangumiPrivateApiBaseUrl;
  final String bangumiOauthClientId;
  final String bangumiOauthClientSecret;
  final String bangumiOauthRedirectUri;
  final String bangumiAccessToken;
  final String bangumiRefreshToken;
  final int bangumiAccessTokenExpiresAt;

  AppConfig copyWith({
    String? llmBaseUrl,
    String? llmApiKey,
    String? llmModel,
    String? bangumiUserAgent,
    String? bangumiPrivateApiBaseUrl,
    String? bangumiOauthClientId,
    String? bangumiOauthClientSecret,
    String? bangumiOauthRedirectUri,
    String? bangumiAccessToken,
    String? bangumiRefreshToken,
    int? bangumiAccessTokenExpiresAt,
  }) {
    return AppConfig(
      llmBaseUrl: llmBaseUrl ?? this.llmBaseUrl,
      llmApiKey: llmApiKey ?? this.llmApiKey,
      llmModel: llmModel ?? this.llmModel,
      bangumiUserAgent: bangumiUserAgent ?? this.bangumiUserAgent,
      bangumiPrivateApiBaseUrl:
          bangumiPrivateApiBaseUrl ?? this.bangumiPrivateApiBaseUrl,
      bangumiOauthClientId:
          bangumiOauthClientId ?? this.bangumiOauthClientId,
      bangumiOauthClientSecret:
          bangumiOauthClientSecret ?? this.bangumiOauthClientSecret,
      bangumiOauthRedirectUri:
          bangumiOauthRedirectUri ?? this.bangumiOauthRedirectUri,
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
      'bangumiUserAgent': bangumiUserAgent,
      'bangumiPrivateApiBaseUrl': bangumiPrivateApiBaseUrl,
      'bangumiOauthClientId': bangumiOauthClientId,
      'bangumiOauthClientSecret': bangumiOauthClientSecret,
      'bangumiOauthRedirectUri': bangumiOauthRedirectUri,
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
      bangumiUserAgent:
          json['bangumiUserAgent']?.toString() ?? defaults.bangumiUserAgent,
      bangumiPrivateApiBaseUrl:
          json['bangumiPrivateApiBaseUrl']?.toString() ??
          defaults.bangumiPrivateApiBaseUrl,
      bangumiOauthClientId:
          json['bangumiOauthClientId']?.toString() ??
          defaults.bangumiOauthClientId,
      bangumiOauthClientSecret:
          json['bangumiOauthClientSecret']?.toString() ??
          defaults.bangumiOauthClientSecret,
      bangumiOauthRedirectUri:
          json['bangumiOauthRedirectUri']?.toString() ??
          defaults.bangumiOauthRedirectUri,
      bangumiAccessToken:
          json['bangumiAccessToken']?.toString() ??
          defaults.bangumiAccessToken,
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

int _asInt(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
