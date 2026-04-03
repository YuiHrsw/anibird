class TimelineUser {
  const TimelineUser({
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

  factory TimelineUser.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final avatar =
        (data['avatar'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return TimelineUser(
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

class TimelineSubjectRef {
  const TimelineSubjectRef({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.image,
  });

  final int id;
  final String name;
  final String nameCn;
  final String image;

  String get displayName => nameCn.isNotEmpty ? nameCn : name;

  factory TimelineSubjectRef.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final images =
        (data['images'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return TimelineSubjectRef(
      id: _asInt(data['id']),
      name: data['name']?.toString() ?? '',
      nameCn: data['nameCN']?.toString() ?? '',
      image:
          images['large']?.toString() ??
          images['common']?.toString() ??
          images['medium']?.toString() ??
          images['grid']?.toString() ??
          images['small']?.toString() ??
          '',
    );
  }
}

class TimelineItem {
  const TimelineItem({
    required this.id,
    required this.uid,
    required this.cat,
    required this.type,
    required this.batch,
    required this.replies,
    required this.createdAt,
    required this.user,
    required this.sourceName,
    required this.sourceUrl,
    required this.summary,
    required this.detail,
    required this.subjects,
  });

  final int id;
  final int uid;
  final int cat;
  final int type;
  final bool batch;
  final int replies;
  final int createdAt;
  final TimelineUser? user;
  final String sourceName;
  final String sourceUrl;
  final String summary;
  final String detail;
  final List<TimelineSubjectRef> subjects;

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    final memo = (json['memo'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final source = (json['source'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final subjects = _collectSubjects(memo);
    final parsedText = _buildText(
      cat: _asInt(json['cat']),
      type: _asInt(json['type']),
      memo: memo,
      subjects: subjects,
    );
    return TimelineItem(
      id: _asInt(json['id']),
      uid: _asInt(json['uid']),
      cat: _asInt(json['cat']),
      type: _asInt(json['type']),
      batch: json['batch'] as bool? ?? false,
      replies: _asInt(json['replies']),
      createdAt: _asInt(json['createdAt']),
      user: TimelineUser.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>(),
      ),
      sourceName: source['name']?.toString() ?? '',
      sourceUrl: source['url']?.toString() ?? '',
      summary: parsedText.$1,
      detail: parsedText.$2,
      subjects: subjects,
    );
  }
}

List<TimelineSubjectRef> _collectSubjects(Map<String, dynamic> memo) {
  final subjects = <TimelineSubjectRef>[];

  final subjectItems = (memo['subject'] as List?)
          ?.whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList() ??
      const <Map<String, dynamic>>[];
  for (final item in subjectItems) {
    final subject = (item['subject'] as Map?)?.cast<String, dynamic>();
    if (subject != null) {
      subjects.add(TimelineSubjectRef.fromJson(subject));
    }
  }

  final wiki = (memo['wiki'] as Map?)?.cast<String, dynamic>();
  final wikiSubject = wiki == null ? null : wiki['subject'];
  if (wikiSubject is Map) {
    subjects.add(TimelineSubjectRef.fromJson(wikiSubject.cast<String, dynamic>()));
  }

  final progress = (memo['progress'] as Map?)?.cast<String, dynamic>();
  final batchSubject = progress == null ? null : progress['batch'];
  if (batchSubject is Map) {
    final subject = (batchSubject['subject'] as Map?)?.cast<String, dynamic>();
    if (subject != null) {
      subjects.add(TimelineSubjectRef.fromJson(subject));
    }
  }

  final singleSubject = progress == null ? null : progress['single'];
  if (singleSubject is Map) {
    final subject = (singleSubject['subject'] as Map?)?.cast<String, dynamic>();
    if (subject != null) {
      subjects.add(TimelineSubjectRef.fromJson(subject));
    }
  }

  final deduped = <int, TimelineSubjectRef>{};
  for (final subject in subjects) {
    deduped[subject.id] = subject;
  }
  return deduped.values.toList(growable: false);
}

(String, String) _buildText({
  required int cat,
  required int type,
  required Map<String, dynamic> memo,
  required List<TimelineSubjectRef> subjects,
}) {
  final status = (memo['status'] as Map?)?.cast<String, dynamic>();
  if (status != null) {
    final sign = status['sign']?.toString() ?? '';
    if (sign.isNotEmpty) {
      return ('更新了签名', sign);
    }
    final tsukkomi = status['tsukkomi']?.toString() ?? '';
    if (tsukkomi.isNotEmpty) {
      return ('发表了吐槽', tsukkomi);
    }
    final nickname = (status['nickname'] as Map?)?.cast<String, dynamic>();
    if (nickname != null) {
      return (
        '修改了昵称',
        '${nickname['before']?.toString() ?? ''} -> ${nickname['after']?.toString() ?? ''}',
      );
    }
  }

  final subjectItems = (memo['subject'] as List?)
          ?.whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList() ??
      const <Map<String, dynamic>>[];
  if (subjectItems.isNotEmpty) {
    final first = subjectItems.first;
    final comment = first['comment']?.toString() ?? '';
    final rate = _asInt(first['rate']);
    final label = _subjectActionLabel(type);
    final detailParts = <String>[
      if (subjects.isNotEmpty) subjects.first.displayName,
      if (comment.isNotEmpty) comment,
      if (rate > 0) '评分 $rate',
    ];
    return (label, detailParts.join(' · '));
  }

  final progress = (memo['progress'] as Map?)?.cast<String, dynamic>();
  if (progress != null) {
    final batch = (progress['batch'] as Map?)?.cast<String, dynamic>();
    if (batch != null) {
      final subject = (batch['subject'] as Map?)?.cast<String, dynamic>();
      final subjectName = TimelineSubjectRef.fromJson(subject).displayName;
      final epsUpdate = _asInt(batch['epsUpdate']);
      final volsUpdate = _asInt(batch['volsUpdate']);
      final parts = <String>[
        if (subjectName.isNotEmpty) subjectName,
        if (epsUpdate > 0) '更新到第 $epsUpdate 集',
        if (volsUpdate > 0) '更新到第 $volsUpdate 卷',
      ];
      return ('更新了进度', parts.join(' · '));
    }
    final single = (progress['single'] as Map?)?.cast<String, dynamic>();
    if (single != null) {
      final subject = (single['subject'] as Map?)?.cast<String, dynamic>();
      final episode = (single['episode'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final subjectName = TimelineSubjectRef.fromJson(subject).displayName;
      final sort = episode['sort']?.toString() ?? '';
      final episodeName =
          episode['nameCN']?.toString() ??
          episode['name']?.toString() ??
          '';
      return (
        _progressActionLabel(type),
        [
          if (subjectName.isNotEmpty) subjectName,
          if (sort.isNotEmpty) '第 $sort 集',
          if (episodeName.isNotEmpty) episodeName,
        ].join(' · '),
      );
    }
  }

  final wiki = (memo['wiki'] as Map?)?.cast<String, dynamic>();
  if (wiki != null) {
    final subject = (wiki['subject'] as Map?)?.cast<String, dynamic>();
    final subjectName = TimelineSubjectRef.fromJson(subject).displayName;
    return ('编辑了条目', subjectName);
  }

  final blog = (memo['blog'] as Map?)?.cast<String, dynamic>();
  if (blog != null) {
    return ('发布了日志', blog['title']?.toString() ?? '');
  }

  final index = (memo['index'] as Map?)?.cast<String, dynamic>();
  if (index != null) {
    return ('更新了目录', index['title']?.toString() ?? '');
  }

  final mono = (memo['mono'] as Map?)?.cast<String, dynamic>();
  if (mono != null) {
    final characters = (mono['characters'] as List?)
            ?.whereType<Map>()
            .map((item) => item['name']?.toString() ?? '')
            .where((item) => item.isNotEmpty) ??
        const Iterable<String>.empty();
    final persons = (mono['persons'] as List?)
            ?.whereType<Map>()
            .map((item) => item['name']?.toString() ?? '')
            .where((item) => item.isNotEmpty) ??
        const Iterable<String>.empty();
    final names = [...characters, ...persons].take(3).join(' / ');
    return ('更新了人物收藏', names);
  }

  final daily = (memo['daily'] as Map?)?.cast<String, dynamic>();
  if (daily != null) {
    return ('更新了日常动态', '');
  }

  return (_categoryLabel(cat), subjects.isNotEmpty ? subjects.first.displayName : '');
}

String _categoryLabel(int cat) {
  switch (cat) {
    case 1:
      return '日常动态';
    case 2:
      return '条目编辑';
    case 3:
      return '收藏更新';
    case 4:
      return '进度更新';
    case 5:
      return '状态更新';
    case 6:
      return '日志动态';
    case 7:
      return '目录动态';
    case 8:
      return '人物动态';
    default:
      return '时间线动态';
  }
}

String _subjectActionLabel(int type) {
  switch (type) {
    case 2:
      return '想看了一部动画';
    case 6:
      return '看过了一部动画';
    case 10:
      return '正在看一部动画';
    case 13:
      return '搁置了一部动画';
    case 14:
      return '抛弃了一部动画';
    default:
      return '更新了收藏';
  }
}

String _progressActionLabel(int type) {
  switch (type) {
    case 1:
      return '想看了这一集';
    case 2:
      return '看过了这一集';
    case 3:
      return '抛弃了这一集';
    default:
      return '更新了单集进度';
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
