import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/repositories/entries_repository.dart';

/// Cancels an entry (`cancelled`) or reopens it (`planned`).
class SetEntryStatus {
  const SetEntryStatus(this._repository);

  final EntriesRepository _repository;

  Future<Result<FinancialEntry>> call(String id, EntryStatus status) =>
      _repository.setStatus(id, status);
}
