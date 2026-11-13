import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/home/domain/entities/upcoming_entry.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

/// The entries that fall due soon and are not reconciled yet.
class GetUpcomingEntries {
  const GetUpcomingEntries(this._repository);

  /// How far ahead the home looks.
  static const defaultDays = 30;

  final HomeRepository _repository;

  Future<Result<List<UpcomingEntry>>> call({
    int days = defaultDays,
    String? userId,
  }) => _repository.upcomingEntries(days: days, userId: userId);
}
