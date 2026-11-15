import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/domain/entities/entry_draft.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/repositories/entries_repository.dart';

/// Creates a planned entry from the form.
class CreateEntry {
  const CreateEntry(this._repository);

  final EntriesRepository _repository;

  Future<Result<FinancialEntry>> call(EntryDraft draft) =>
      _repository.create(draft);
}
