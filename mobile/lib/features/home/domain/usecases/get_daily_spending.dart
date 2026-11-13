import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/home/domain/entities/daily_amount.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

/// What was spent in each day of a period.
class GetDailySpending {
  const GetDailySpending(this._repository);

  final HomeRepository _repository;

  Future<Result<List<DailyAmount>>> call(DateRange range, {String? userId}) =>
      _repository.dailyExpenses(range, userId: userId);
}
