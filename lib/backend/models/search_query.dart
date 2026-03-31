class SearchQuery {
  const SearchQuery({
    required this.keyword,
    this.tags = const <String>[],
    this.metaTags = const <String>[],
    this.sort = 'match',
    this.limit = 12,
    this.offset = 0,
    this.types = const <int>[2],
  });

  final String keyword;
  final List<String> tags;
  final List<String> metaTags;
  final String sort;
  final int limit;
  final int offset;
  final List<int> types;

  Map<String, dynamic> toJson() {
    return {
      'keyword': keyword,
      'sort': _normalizeSearchSort(sort),
      'filter': {
        'type': types,
        if (tags.isNotEmpty) 'tag': tags,
        if (metaTags.isNotEmpty) 'meta_tags': metaTags,
      },
    };
  }
}

String _normalizeSearchSort(String value) {
  switch (value.trim()) {
    case 'match':
    case 'heat':
    case 'rank':
    case 'score':
      return value.trim();
    default:
      return 'match';
  }
}
