import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/transactions/domain/repositories/transactions_repository.dart';

/// Undoes the link of a bank transaction with an entry.
class UnlinkTransactionEntry {
  const UnlinkTransactionEntry(this._repository);

  final TransactionsRepository _repository;

  Future<Result<void>> call(String transactionId, String entryId) =>
      _repository.unlinkEntry(transactionId, entryId);
}
