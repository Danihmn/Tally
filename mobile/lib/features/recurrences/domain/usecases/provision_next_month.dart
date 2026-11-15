import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/repositories/recurrences_repository.dart';

/// Creates next month's entries from the recurrences.
class ProvisionNextMonth {
  const ProvisionNextMonth(this._repository);

  final RecurrencesRepository _repository;

  Future<Result<ProvisionResult>> call() => _repository.provisionNextMonth();
}
