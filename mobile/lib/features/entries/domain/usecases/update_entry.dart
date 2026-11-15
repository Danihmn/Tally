import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/domain/entities/entry_draft.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/repositories/entries_repository.dart';

/// Replaces the editable data of an entry with what the form has.
class UpdateEntry {
  const UpdateEntry(this._repository);

  final EntriesRepository _repository;

  Future<Result<FinancialEntry>> call(String id, EntryDraft draft) =>
      _repository.update(id, draft);
}
