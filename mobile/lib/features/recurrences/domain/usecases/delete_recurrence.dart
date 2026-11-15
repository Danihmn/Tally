import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/domain/repositories/recurrences_repository.dart';

/// Deletes a recurrence. The entries it created stay.
class DeleteRecurrence {
  const DeleteRecurrence(this._repository);

  final RecurrencesRepository _repository;

  Future<Result<void>> call(String id) => _repository.delete(id);
}
