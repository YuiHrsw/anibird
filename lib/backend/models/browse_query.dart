class BrowseQuery {
  const BrowseQuery({
    this.type = 2,
    this.sort = 'rank',
    this.year,
    this.month,
    this.limit = 12,
    this.offset = 0,
  });

  final int type;
  final String sort;
  final int? year;
  final int? month;
  final int limit;
  final int offset;
}
