import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';

/// The list of transactions.
abstract interface class TransactionsRepository {
  /// One page of the transactions of the house, newest first. [userId] limits
  /// it to one person (without it, the whole house). [search] is a text inside
  /// the description.
  Future<Result<PageResult<Transaction>>> search({
    required int offset,
    required int limit,
    String? userId,
    TransactionFilters filters = const TransactionFilters(),
    String search = '',
  });
}
