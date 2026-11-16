import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/transactions/data/datasources/transactions_remote_data_source.dart';
import 'package:mobile/features/transactions/data/mappers/transaction_mapper.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';
import 'package:mobile/features/transactions/domain/repositories/transactions_repository.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  const TransactionsRepositoryImpl(this._remote);

  final TransactionsRemoteDataSource _remote;

  @override
  Future<Result<PageResult<Transaction>>> search({
    required int offset,
    required int limit,
    String? userId,
    TransactionFilters filters = const TransactionFilters(),
    String search = '',
    String? financialEntryId,
  }) async {
    final result = await _remote.search(
      offset: offset,
      limit: limit,
      userId: userId,
      filters: filters,
      search: search,
      financialEntryId: financialEntryId,
    );
    return result.map(
      (page) => PageResult<Transaction>(
        items: [for (final dto in page.items) dto.toEntity()],
        limit: page.limit,
        offset: page.offset,
        total: page.total,
      ),
    );
  }

  @override
  Future<Result<void>> linkEntry(String transactionId, String entryId) =>
      _remote.linkEntry(transactionId, entryId);

  @override
  Future<Result<void>> unlinkEntry(String transactionId, String entryId) =>
      _remote.unlinkEntry(transactionId, entryId);
}
