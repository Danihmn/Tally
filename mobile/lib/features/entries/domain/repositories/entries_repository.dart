import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';

/// The planned entries of the house.
abstract interface class EntriesRepository {
  /// One page of entries. [userId] limits it to one person (without it, the
  /// whole house). [status] is the tab. [referenceMonth] is any day of one
  /// month (without it, every month). [search] is a text inside the
  /// description. [transactionId] keeps only the entries matched with that bank
  /// transaction.
  Future<Result<PageResult<FinancialEntry>>> search({
    required int offset,
    required int limit,
    String? userId,
    EntryStatus? status,
    DateTime? referenceMonth,
    EntryFilters filters = const EntryFilters(),
    String search = '',
    String? transactionId,
  });
}
