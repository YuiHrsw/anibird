class BlogCommentUser {
  const BlogCommentUser({
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

  factory BlogCommentUser.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final avatar =
        (data['avatar'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return BlogCommentUser(
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

class BlogCommentReply {
  const BlogCommentReply({
    required this.id,
    required this.creatorId,
    required this.createdAt,
    required this.content,
    required this.state,
    required this.user,
  });

  final int id;
  final int creatorId;
  final int createdAt;
  final String content;
  final int state;
  final BlogCommentUser? user;

  factory BlogCommentReply.fromJson(Map<String, dynamic> json) {
    return BlogCommentReply(
      id: _asInt(json['id']),
      creatorId: _asInt(json['creatorID']),
      createdAt: _asInt(json['createdAt']),
      content: json['content']?.toString() ?? '',
      state: _asInt(json['state']),
      user: (json['creator'] as Map?) == null
          ? null
          : BlogCommentUser.fromJson(
              (json['creator'] as Map).cast<String, dynamic>(),
            ),
    );
  }
}

class BlogComment {
  const BlogComment({
    required this.id,
    required this.creatorId,
    required this.createdAt,
    required this.content,
    required this.state,
    required this.user,
    required this.replies,
  });

  final int id;
  final int creatorId;
  final int createdAt;
  final String content;
  final int state;
  final BlogCommentUser? user;
  final List<BlogCommentReply> replies;

  factory BlogComment.fromJson(Map<String, dynamic> json) {
    return BlogComment(
      id: _asInt(json['id']),
      creatorId: _asInt(json['creatorID']),
      createdAt: _asInt(json['createdAt']),
      content: json['content']?.toString() ?? '',
      state: _asInt(json['state']),
      user: (json['creator'] as Map?) == null
          ? null
          : BlogCommentUser.fromJson(
              (json['creator'] as Map).cast<String, dynamic>(),
            ),
      replies: (json['replies'] as List?)
              ?.whereType<Map>()
              .map((item) => BlogCommentReply.fromJson(item.cast<String, dynamic>()))
              .toList(growable: false) ??
          const <BlogCommentReply>[],
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
