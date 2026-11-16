import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/transactions/domain/repositories/transactions_repository.dart';

/// Links a bank transaction with a planned entry by hand.
class LinkTransactionEntry {
  const LinkTransactionEntry(this._repository);

  final TransactionsRepository _repository;

  Future<Result<void>> call(String transactionId, String entryId) =>
      _repository.linkEntry(transactionId, entryId);
}
