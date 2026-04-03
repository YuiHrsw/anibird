class SubjectReviewUser {
  const SubjectReviewUser({
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

  factory SubjectReviewUser.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return SubjectReviewUser(
      id: _asInt(data['id']),
      username: data['username']?.toString() ?? '',
      nickname: data['nickname']?.toString() ?? '',
      avatar: data['avatar']?.toString() ?? '',
    );
  }
}

class SubjectReviewEntry {
  const SubjectReviewEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.replies,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String summary;
  final int replies;
  final int createdAt;
  final int updatedAt;

  factory SubjectReviewEntry.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return SubjectReviewEntry(
      id: _asInt(data['id']),
      title: data['title']?.toString() ?? '',
      summary: data['summary']?.toString() ?? '',
      replies: _asInt(data['replies']),
      createdAt: _asInt(data['createdAt']),
      updatedAt: _asInt(data['updatedAt']),
    );
  }
}

class SubjectReview {
  const SubjectReview({
    required this.id,
    required this.user,
    required this.entry,
  });

  final int id;
  final SubjectReviewUser? user;
  final SubjectReviewEntry entry;

  factory SubjectReview.fromJson(Map<String, dynamic> json) {
    return SubjectReview(
      id: _asInt(json['id']),
      user: (json['user'] as Map?) == null
          ? null
          : SubjectReviewUser.fromJson(
              (json['user'] as Map).cast<String, dynamic>(),
            ),
      entry: SubjectReviewEntry.fromJson(
        (json['entry'] as Map?)?.cast<String, dynamic>(),
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
