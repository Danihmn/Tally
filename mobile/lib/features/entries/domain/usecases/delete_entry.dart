import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/domain/repositories/entries_repository.dart';

/// Deletes an entry that is not reconciled.
class DeleteEntry {
  const DeleteEntry(this._repository);

  final EntriesRepository _repository;

  Future<Result<void>> call(String id) => _repository.delete(id);
}
