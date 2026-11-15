import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/repositories/recurrences_repository.dart';

/// Replaces the data of a recurrence with what the form has.
class UpdateRecurrence {
  const UpdateRecurrence(this._repository);

  final RecurrencesRepository _repository;

  Future<Result<Recurrence>> call(String id, RecurrenceDraft draft) =>
      _repository.update(id, draft);
}
