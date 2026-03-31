class RelatedPerson {
  const RelatedPerson({
    required this.id,
    required this.name,
    required this.relation,
    required this.careers,
    required this.eps,
    required this.image,
  });

  final int id;
  final String name;
  final String relation;
  final List<String> careers;
  final String eps;
  final String image;

  factory RelatedPerson.fromJson(Map<String, dynamic> json) {
    final images =
        (json['images'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return RelatedPerson(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      relation: json['relation']?.toString() ?? '',
      careers:
          (json['career'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const <String>[],
      eps: json['eps']?.toString() ?? '',
      image:
          images['medium']?.toString() ??
          images['grid']?.toString() ??
          images['small']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relation': relation,
      'career': careers,
      'eps': eps,
      'image': image,
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
