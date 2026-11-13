import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';
import 'package:mobile/features/transactions/domain/repositories/transactions_repository.dart';

/// Loads one page of transactions with the search text and the filters.
class SearchTransactions {
  const SearchTransactions(this._repository);

  final TransactionsRepository _repository;

  Future<Result<PageResult<Transaction>>> call({
    required int offset,
    required int limit,
    String? userId,
    TransactionFilters filters = const TransactionFilters(),
    String search = '',
  }) => _repository.search(
    offset: offset,
    limit: limit,
    userId: userId,
    filters: filters,
    search: search,
  );
}
