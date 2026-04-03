class BangumiPermissions {
  const BangumiPermissions({
    required this.subjectWikiEdit,
  });

  final bool subjectWikiEdit;

  factory BangumiPermissions.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return BangumiPermissions(
      subjectWikiEdit: data['subjectWikiEdit'] as bool? ?? false,
    );
  }
}

class BangumiProfile {
  const BangumiProfile({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
    required this.sign,
    required this.group,
    required this.joinedAt,
    required this.site,
    required this.location,
    required this.permissions,
  });

  final int id;
  final String username;
  final String nickname;
  final String avatar;
  final String sign;
  final int group;
  final int joinedAt;
  final String site;
  final String location;
  final BangumiPermissions permissions;

  String get displayName => nickname.isNotEmpty ? nickname : username;

  factory BangumiProfile.fromJson(Map<String, dynamic> json) {
    return BangumiProfile(
      id: _asInt(json['id']),
      username: json['username']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      sign: json['sign']?.toString() ?? '',
      group: _asInt(json['group']),
      joinedAt: _asInt(json['joinedAt']),
      site: json['site']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      permissions: BangumiPermissions.fromJson(
        (json['permissions'] as Map?)?.cast<String, dynamic>(),
      ),
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
