import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/top_expense.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

/// The biggest expenses of a period.
class GetTopExpenses {
  const GetTopExpenses(this._repository);

  /// How many the home shows.
  static const defaultLimit = 5;

  final HomeRepository _repository;

  Future<Result<List<TopExpense>>> call(
    DateRange range, {
    String? userId,
    int limit = defaultLimit,
  }) => _repository.topExpenses(range, limit: limit, userId: userId);
}
