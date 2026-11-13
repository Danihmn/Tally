import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/spending_summary.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

/// Spent, received, balance and the daily average of a period.
class GetSpendingSummary {
  const GetSpendingSummary(this._repository);

  final HomeRepository _repository;

  Future<Result<SpendingSummary>> call(
    DateRange range, {
    String? userId,
  }) async {
    final (spent, received, balance, average) = await (
      _repository.totalExpenses(range, userId: userId),
      _repository.totalRevenues(range, userId: userId),
      _repository.balance(range, userId: userId),
      _repository.averageDailyExpenses(range, userId: userId),
    ).wait;

    final failure =
        spent.failureOrNull ??
        received.failureOrNull ??
        balance.failureOrNull ??
        average.failureOrNull;
    if (failure != null) return Result.failure(failure);

    return Result.success(
      SpendingSummary(
        spent: spent.valueOrNull!,
        received: received.valueOrNull!,
        balance: balance.valueOrNull!,
        averagePerDay: average.valueOrNull!,
      ),
    );
  }
}
