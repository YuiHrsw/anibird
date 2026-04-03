class Episode {
  const Episode({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.sort,
    this.ep,
    required this.airdate,
    required this.comment,
    required this.duration,
    required this.desc,
    required this.disc,
    this.subjectId,
    this.durationSeconds = 0,
    this.collection,
  });

  final int id;
  final int type;
  final String name;
  final String nameCn;
  final double sort;
  final double? ep;
  final String airdate;
  final int comment;
  final String duration;
  final String desc;
  final int disc;
  final int? subjectId;
  final int durationSeconds;
  final EpisodeCollection? collection;

  String get displayName => nameCn.isNotEmpty ? nameCn : name;

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: _asInt(json['id']),
      type: _asInt(json['type']),
      name: json['name']?.toString() ?? '',
      nameCn: json['name_cn']?.toString() ?? '',
      sort: _asDouble(json['sort']),
      ep: json['ep'] == null ? null : _asDouble(json['ep']),
      airdate: json['airdate']?.toString() ?? '',
      comment: _asInt(json['comment']),
      duration: json['duration']?.toString() ?? '',
      desc: json['desc']?.toString() ?? '',
      disc: _asInt(json['disc']),
      subjectId: json['subject_id'] == null ? null : _asInt(json['subject_id']),
      durationSeconds: _asInt(json['duration_seconds']),
      collection: (json['collection'] as Map?) == null
          ? null
          : EpisodeCollection.fromJson(
              (json['collection'] as Map).cast<String, dynamic>(),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'name_cn': nameCn,
      'sort': sort,
      'ep': ep,
      'airdate': airdate,
      'comment': comment,
      'duration': duration,
      'desc': desc,
      'disc': disc,
      'subject_id': subjectId,
      'duration_seconds': durationSeconds,
      'collection': collection == null
          ? null
          : {
              'status': collection!.status,
              'updatedAt': collection!.updatedAt,
            },
    };
  }
}

class EpisodeCollection {
  const EpisodeCollection({
    required this.status,
    this.updatedAt,
  });

  final int status;
  final int? updatedAt;

  bool get isDone => status == 2;

  factory EpisodeCollection.fromJson(Map<String, dynamic> json) {
    return EpisodeCollection(
      status: _asInt(json['status']),
      updatedAt: json['updatedAt'] == null ? null : _asInt(json['updatedAt']),
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

double _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
