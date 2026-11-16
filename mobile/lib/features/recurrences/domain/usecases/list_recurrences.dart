import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/repositories/recurrences_repository.dart';

/// Loads the recurrences of the house with a status (active or cancelled).
class ListRecurrences {
  const ListRecurrences(this._repository);

  final RecurrencesRepository _repository;

  Future<Result<List<Recurrence>>> call(RecurrenceStatus status) =>
      _repository.list(status);
}
