import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/repositories/recurrences_repository.dart';

/// Loads every recurrence of the house.
class ListRecurrences {
  const ListRecurrences(this._repository);

  final RecurrencesRepository _repository;

  Future<Result<List<Recurrence>>> call() => _repository.list();
}
