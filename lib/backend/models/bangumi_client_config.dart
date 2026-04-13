class BangumiClientConfig {
  const BangumiClientConfig({
    required this.oauthClientId,
    required this.oauthClientSecret,
  });

  static const String userAgent = 'Anibird/0.1.0 (Flutter)';
  static const String privateApiBaseUrl = 'https://next.bgm.tv/p1';
  static const String oauthRedirectUri = 'anibird://oauth/callback';

  final String oauthClientId;
  final String oauthClientSecret;

  bool get hasOauthCredentials =>
      oauthClientId.trim().isNotEmpty && oauthClientSecret.trim().isNotEmpty;
}
