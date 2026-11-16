import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';

/// The recurrences of the house.
abstract interface class RecurrencesRepository {
  /// The recurrences of the house with [status], by description.
  Future<Result<List<Recurrence>>> list(RecurrenceStatus status);

  Future<Result<Recurrence>> create(RecurrenceDraft draft);

  /// Replaces the data of a recurrence. Entries already created from it are
  /// not changed.
  Future<Result<Recurrence>> update(String id, RecurrenceDraft draft);

  /// Cancels a recurrence (it stops creating entries) or reactivates it.
  Future<Result<Recurrence>> setStatus(String id, RecurrenceStatus status);

  /// Deletes a recurrence. Entries already created from it stay.
  Future<Result<void>> delete(String id);

  /// Creates next month's entries from the active recurrences. A recurrence that
  /// already has its entry in that month is skipped. Fails with
  /// `NoRecurrencesFailure` when there is none.
  Future<Result<ProvisionResult>> provisionNextMonth();
}
