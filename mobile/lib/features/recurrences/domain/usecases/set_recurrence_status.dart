import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/repositories/recurrences_repository.dart';

/// Cancels a recurrence or reactivates it.
class SetRecurrenceStatus {
  const SetRecurrenceStatus(this._repository);

  final RecurrencesRepository _repository;

  Future<Result<Recurrence>> call(String id, RecurrenceStatus status) =>
      _repository.setStatus(id, status);
}
