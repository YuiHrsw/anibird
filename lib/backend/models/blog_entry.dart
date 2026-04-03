class BlogEntryUser {
  const BlogEntryUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
  });

  final int id;
  final String username;
  final String nickname;
  final String avatar;

  String get displayName => nickname.isNotEmpty ? nickname : username;

  factory BlogEntryUser.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final avatar =
        (data['avatar'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return BlogEntryUser(
      id: _asInt(data['id']),
      username: data['username']?.toString() ?? '',
      nickname: data['nickname']?.toString() ?? '',
      avatar:
          avatar['large']?.toString() ??
          avatar['medium']?.toString() ??
          avatar['small']?.toString() ??
          '',
    );
  }
}

class BlogEntry {
  const BlogEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.replies,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
  });

  final int id;
  final String title;
  final String content;
  final int replies;
  final int createdAt;
  final int updatedAt;
  final BlogEntryUser? user;

  factory BlogEntry.fromJson(Map<String, dynamic> json) {
    return BlogEntry(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      replies: _asInt(json['replies']),
      createdAt: _asInt(json['createdAt']),
      updatedAt: _asInt(json['updatedAt']),
      user: (json['user'] as Map?) == null
          ? null
          : BlogEntryUser.fromJson((json['user'] as Map).cast<String, dynamic>()),
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
