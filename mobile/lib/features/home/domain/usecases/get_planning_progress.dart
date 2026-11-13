import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/entry_type.dart';
import 'package:mobile/features/home/domain/entities/planning_progress.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

/// "Planned against real" of a month.
///
/// The amounts are the expenses (what the card shows). The counts include
/// revenues too, like the prototype: "k of n entries reconciled".
class GetPlanningProgress {
  const GetPlanningProgress(this._repository);

  final HomeRepository _repository;

  Future<Result<PlanningProgress>> call(
    DateRange month, {
    String? userId,
  }) async {
    final (planned, reconciled, expenseCounts, revenueCounts) = await (
      _repository.totalPlanned(month, EntryType.expenses, userId: userId),
      _repository.totalReconciled(month, EntryType.expenses, userId: userId),
      _repository.reconciliationCounts(
        month,
        EntryType.expenses,
        userId: userId,
      ),
      _repository.reconciliationCounts(
        month,
        EntryType.revenues,
        userId: userId,
      ),
    ).wait;

    final failure =
        planned.failureOrNull ??
        reconciled.failureOrNull ??
        expenseCounts.failureOrNull ??
        revenueCounts.failureOrNull;
    if (failure != null) return Result.failure(failure);

    final expenses = expenseCounts.valueOrNull!;
    final revenues = revenueCounts.valueOrNull!;
    return Result.success(
      PlanningProgress(
        planned: planned.valueOrNull!,
        reconciled: reconciled.valueOrNull!,
        reconciledCount: expenses.reconciled + revenues.reconciled,
        notReconciledCount: expenses.notReconciled + revenues.notReconciled,
      ),
    );
  }
}
