import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/repositories/entries_repository.dart';

/// Loads one page of entries with the tab, the month, the search text and the
/// filters.
class SearchEntries {
  const SearchEntries(this._repository);

  final EntriesRepository _repository;

  Future<Result<PageResult<FinancialEntry>>> call({
    required int offset,
    required int limit,
    String? userId,
    EntryStatus? status,
    DateTime? referenceMonth,
    EntryFilters filters = const EntryFilters(),
    String search = '',
    String? transactionId,
  }) => _repository.search(
    offset: offset,
    limit: limit,
    userId: userId,
    status: status,
    referenceMonth: referenceMonth,
    filters: filters,
    search: search,
    transactionId: transactionId,
  );
}
