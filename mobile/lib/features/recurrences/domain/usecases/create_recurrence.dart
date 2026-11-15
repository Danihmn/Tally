import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/repositories/recurrences_repository.dart';

/// Creates a recurrence from the form.
class CreateRecurrence {
  const CreateRecurrence(this._repository);

  final RecurrencesRepository _repository;

  Future<Result<Recurrence>> call(RecurrenceDraft draft) =>
      _repository.create(draft);
}
