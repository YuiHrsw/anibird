class BangumiOAuthToken {
  const BangumiOAuthToken({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
    required this.refreshToken,
    required this.userId,
    this.scope,
  });

  final String accessToken;
  final int expiresIn;
  final String tokenType;
  final String refreshToken;
  final String userId;
  final String? scope;

  factory BangumiOAuthToken.fromJson(Map<String, dynamic> json) {
    return BangumiOAuthToken(
      accessToken: json['access_token']?.toString() ?? '',
      expiresIn: _asInt(json['expires_in']),
      tokenType: json['token_type']?.toString() ?? 'Bearer',
      refreshToken: json['refresh_token']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      scope: json['scope']?.toString(),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
