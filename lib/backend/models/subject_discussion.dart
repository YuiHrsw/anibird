class SubjectDiscussionUser {
  const SubjectDiscussionUser({
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

  factory SubjectDiscussionUser.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return SubjectDiscussionUser(
      id: _asInt(data['id']),
      username: data['username']?.toString() ?? '',
      nickname: data['nickname']?.toString() ?? '',
      avatar: data['avatar']?.toString() ?? '',
    );
  }
}

class SubjectComment {
  const SubjectComment({
    required this.id,
    required this.user,
    required this.type,
    required this.rate,
    required this.comment,
    required this.updatedAt,
  });

  final int id;
  final SubjectDiscussionUser? user;
  final int type;
  final int rate;
  final String comment;
  final int updatedAt;

  factory SubjectComment.fromJson(Map<String, dynamic> json) {
    return SubjectComment(
      id: _asInt(json['id']),
      user: (json['user'] as Map?) == null
          ? null
          : SubjectDiscussionUser.fromJson(
              (json['user'] as Map).cast<String, dynamic>(),
            ),
      type: _asInt(json['type']),
      rate: _asInt(json['rate']),
      comment: json['comment']?.toString() ?? '',
      updatedAt: _asInt(json['updatedAt']),
    );
  }
}

class SubjectTopic {
  const SubjectTopic({
    required this.id,
    required this.title,
    required this.creatorId,
    required this.creator,
    required this.parentId,
    required this.replyCount,
    required this.createdAt,
    required this.updatedAt,
    required this.state,
    required this.display,
  });

  final int id;
  final String title;
  final int creatorId;
  final SubjectDiscussionUser? creator;
  final int parentId;
  final int replyCount;
  final int createdAt;
  final int updatedAt;
  final int state;
  final int display;

  factory SubjectTopic.fromJson(Map<String, dynamic> json) {
    return SubjectTopic(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      creatorId: _asInt(json['creatorID']),
      creator: (json['creator'] as Map?) == null
          ? null
          : SubjectDiscussionUser.fromJson(
              (json['creator'] as Map).cast<String, dynamic>(),
            ),
      parentId: _asInt(json['parentID']),
      replyCount: _asInt(json['replyCount']),
      createdAt: _asInt(json['createdAt']),
      updatedAt: _asInt(json['updatedAt']),
      state: _asInt(json['state']),
      display: _asInt(json['display']),
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
