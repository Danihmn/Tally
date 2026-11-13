/// One page returned by a list endpoint (`limit`/`offset`).
///
/// [total] is `null` for endpoints that return a plain list (bank accounts,
/// users). Then "has more" is guessed: a full page means maybe more.
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.limit,
    required this.offset,
    this.total,
  });

  final List<T> items;
  final int limit;
  final int offset;
  final int? total;
}
