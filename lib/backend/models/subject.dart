class SubjectTag {
  const SubjectTag({required this.name, required this.count});

  final String name;
  final int count;

  factory SubjectTag.fromJson(Map<String, dynamic> json) {
    return SubjectTag(
      name: json['name']?.toString() ?? '',
      count: _asInt(json['count']),
    );
  }
}

class SubjectRating {
  const SubjectRating({
    required this.rank,
    required this.total,
    required this.score,
  });

  final int rank;
  final int total;
  final double score;

  factory SubjectRating.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return SubjectRating(
      rank: _asInt(data['rank']),
      total: _asInt(data['total']),
      score: _asDouble(data['score']),
    );
  }
}

class SubjectCollectionStats {
  const SubjectCollectionStats({
    required this.wish,
    required this.collect,
    required this.doing,
    required this.onHold,
    required this.dropped,
  });

  final int wish;
  final int collect;
  final int doing;
  final int onHold;
  final int dropped;

  factory SubjectCollectionStats.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return SubjectCollectionStats(
      wish: _asInt(data['wish']),
      collect: _asInt(data['collect']),
      doing: _asInt(data['doing']),
      onHold: _asInt(data['on_hold']),
      dropped: _asInt(data['dropped']),
    );
  }
}

class SubjectInterest {
  const SubjectInterest({
    required this.id,
    required this.rate,
    required this.type,
    required this.comment,
    required this.tags,
    required this.updatedAt,
    this.epStatus = 0,
    this.volStatus = 0,
    this.isPrivate = false,
  });

  final int id;
  final int rate;
  final int type;
  final String comment;
  final List<String> tags;
  final int updatedAt;
  final int epStatus;
  final int volStatus;
  final bool isPrivate;

  factory SubjectInterest.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return SubjectInterest(
      id: _asInt(data['id']),
      rate: _asInt(data['rate']),
      type: _asInt(data['type']),
      comment: data['comment']?.toString() ?? '',
      tags: (data['tags'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const <String>[],
      updatedAt: _asInt(data['updatedAt']),
      epStatus: _asInt(data['epStatus']),
      volStatus: _asInt(data['volStatus']),
      isPrivate: data['private'] as bool? ?? false,
    );
  }
}

class Subject {
  const Subject({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.date,
    required this.platform,
    required this.image,
    required this.rank,
    required this.score,
    required this.total,
    required this.tags,
    required this.metaTags,
    required this.totalEpisodes,
    required this.eps,
    required this.relation,
    required this.collectionStats,
    this.interest,
  });

  final int id;
  final int type;
  final String name;
  final String nameCn;
  final String summary;
  final String date;
  final String platform;
  final String image;
  final int rank;
  final double score;
  final int total;
  final List<SubjectTag> tags;
  final List<String> metaTags;
  final int totalEpisodes;
  final int eps;
  final String? relation;
  final SubjectCollectionStats collectionStats;
  final SubjectInterest? interest;

  String get displayName => nameCn.isNotEmpty ? nameCn : name;

  factory Subject.fromJson(Map<String, dynamic> json) {
    final images =
        (json['images'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rating = SubjectRating.fromJson(
      (json['rating'] as Map?)?.cast<String, dynamic>(),
    );
    final collection = SubjectCollectionStats.fromJson(
      (json['collection'] as Map?)?.cast<String, dynamic>(),
    );
    final interest = (json['interest'] as Map?)?.cast<String, dynamic>();
    final tags =
        (json['tags'] as List?)
            ?.whereType<Map>()
            .map((item) => SubjectTag.fromJson(item.cast<String, dynamic>()))
            .toList() ??
        const <SubjectTag>[];
    final metaTags =
        (json['meta_tags'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];

    return Subject(
      id: _asInt(json['id']),
      type: _asInt(json['type']),
      name: json['name']?.toString() ?? '',
      nameCn: json['name_cn']?.toString() ?? '',
      summary:
          json['summary']?.toString() ??
          json['short_summary']?.toString() ??
          '',
      date: json['date']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      image:
          json['image']?.toString() ??
          images['large']?.toString() ??
          images['common']?.toString() ??
          images['medium']?.toString() ??
          images['grid']?.toString() ??
          images['small']?.toString() ??
          '',
      rank: rating.rank == 0 ? _asInt(json['rank']) : rating.rank,
      score: rating.score == 0 ? _asDouble(json['score']) : rating.score,
      total: rating.total == 0
          ? _asInt(json['collection_total'])
          : rating.total,
      tags: tags,
      metaTags: metaTags,
      totalEpisodes: _asInt(json['total_episodes']),
      eps: _asInt(json['eps']),
      relation: json['relation']?.toString(),
      collectionStats: collection,
      interest: interest == null ? null : SubjectInterest.fromJson(interest),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'name_cn': nameCn,
      'summary': summary,
      'date': date,
      'platform': platform,
      'image': image,
      'rank': rank,
      'score': score,
      'total': total,
      'relation': relation,
      'interest': interest == null
          ? null
          : {
              'id': interest!.id,
              'rate': interest!.rate,
              'type': interest!.type,
              'comment': interest!.comment,
              'tags': interest!.tags,
              'updatedAt': interest!.updatedAt,
              'epStatus': interest!.epStatus,
              'volStatus': interest!.volStatus,
              'private': interest!.isPrivate,
            },
      'tags': tags
          .map((tag) => {'name': tag.name, 'count': tag.count})
          .toList(growable: false),
      'meta_tags': metaTags,
      'total_episodes': totalEpisodes,
      'eps': eps,
    };
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

double _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
