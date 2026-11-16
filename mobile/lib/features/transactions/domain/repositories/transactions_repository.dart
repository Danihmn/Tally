import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';

/// The list of transactions and their manual link with entries.
abstract interface class TransactionsRepository {
  /// One page of the transactions of the house, newest first. [userId] limits
  /// it to one person (without it, the whole house). [search] is a text inside
  /// the description. [financialEntryId] keeps only the transactions matched
  /// with that entry.
  Future<Result<PageResult<Transaction>>> search({
    required int offset,
    required int limit,
    String? userId,
    TransactionFilters filters = const TransactionFilters(),
    String search = '',
    String? financialEntryId,
  });

  /// Links a transaction with an entry by hand: the entry becomes reconciled.
  Future<Result<void>> linkEntry(String transactionId, String entryId);

  /// Undoes the link. The entry goes back to planned when it has no other.
  Future<Result<void>> unlinkEntry(String transactionId, String entryId);
}
