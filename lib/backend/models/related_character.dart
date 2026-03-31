class RelatedCharacter {
  const RelatedCharacter({
    required this.id,
    required this.name,
    required this.summary,
    required this.relation,
    required this.image,
    required this.actors,
  });

  final int id;
  final String name;
  final String summary;
  final String relation;
  final String image;
  final List<String> actors;

  factory RelatedCharacter.fromJson(Map<String, dynamic> json) {
    final images =
        (json['images'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final actors =
        (json['actors'] as List?)
            ?.whereType<Map>()
            .map((item) => item['name']?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];
    return RelatedCharacter(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      relation: json['relation']?.toString() ?? '',
      image:
          images['medium']?.toString() ??
          images['grid']?.toString() ??
          images['small']?.toString() ??
          '',
      actors: actors,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'summary': summary,
      'relation': relation,
      'image': image,
      'actors': actors,
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
