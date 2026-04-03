class EpisodeCommentUser {
  const EpisodeCommentUser({
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

  factory EpisodeCommentUser.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return EpisodeCommentUser(
      id: _asInt(data['id']),
      username: data['username']?.toString() ?? '',
      nickname: data['nickname']?.toString() ?? '',
      avatar: data['avatar']?.toString() ?? '',
    );
  }
}

class EpisodeComment {
  const EpisodeComment({
    required this.id,
    required this.mainId,
    required this.creatorId,
    required this.relatedId,
    required this.createdAt,
    required this.content,
    required this.state,
    required this.user,
    required this.replies,
  });

  final int id;
  final int mainId;
  final int creatorId;
  final int relatedId;
  final int createdAt;
  final String content;
  final int state;
  final EpisodeCommentUser? user;
  final List<EpisodeCommentReply> replies;

  factory EpisodeComment.fromJson(Map<String, dynamic> json) {
    return EpisodeComment(
      id: _asInt(json['id']),
      mainId: _asInt(json['mainID']),
      creatorId: _asInt(json['creatorID']),
      relatedId: _asInt(json['relatedID']),
      createdAt: _asInt(json['createdAt']),
      content: json['content']?.toString() ?? '',
      state: _asInt(json['state']),
      user: (json['user'] as Map?) == null
          ? null
          : EpisodeCommentUser.fromJson(
              (json['user'] as Map).cast<String, dynamic>(),
            ),
      replies: (json['replies'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => EpisodeCommentReply.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList() ??
          const <EpisodeCommentReply>[],
    );
  }
}

class EpisodeCommentReply {
  const EpisodeCommentReply({
    required this.id,
    required this.mainId,
    required this.creatorId,
    required this.relatedId,
    required this.createdAt,
    required this.content,
    required this.state,
    required this.user,
  });

  final int id;
  final int mainId;
  final int creatorId;
  final int relatedId;
  final int createdAt;
  final String content;
  final int state;
  final EpisodeCommentUser? user;

  factory EpisodeCommentReply.fromJson(Map<String, dynamic> json) {
    return EpisodeCommentReply(
      id: _asInt(json['id']),
      mainId: _asInt(json['mainID']),
      creatorId: _asInt(json['creatorID']),
      relatedId: _asInt(json['relatedID']),
      createdAt: _asInt(json['createdAt']),
      content: json['content']?.toString() ?? '',
      state: _asInt(json['state']),
      user: (json['user'] as Map?) == null
          ? null
          : EpisodeCommentUser.fromJson(
              (json['user'] as Map).cast<String, dynamic>(),
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
