import 'package:decimal/decimal.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/home/domain/entities/daily_amount.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/entry_type.dart';
import 'package:mobile/features/home/domain/entities/reconciliation_counts.dart';
import 'package:mobile/features/home/domain/entities/top_expense.dart';
import 'package:mobile/features/home/domain/entities/upcoming_entry.dart';

/// The numbers of the home. Every method is one API call. [userId] is a
/// person of the house; without it the numbers are for the whole house.
abstract interface class HomeRepository {
  Future<Result<Decimal>> totalExpenses(DateRange range, {String? userId});

  Future<Result<Decimal>> totalRevenues(DateRange range, {String? userId});

  Future<Result<Decimal>> balance(DateRange range, {String? userId});

  Future<Result<Decimal>> averageDailyExpenses(
    DateRange range, {
    String? userId,
  });

  /// One item per day of [range], oldest first, with zero on days without
  /// spending.
  Future<Result<List<DailyAmount>>> dailyExpenses(
    DateRange range, {
    String? userId,
  });

  /// The biggest expenses of [range], the biggest first.
  Future<Result<List<TopExpense>>> topExpenses(
    DateRange range, {
    required int limit,
    String? userId,
  });

  /// Planning is by month: any day of a month picks that month.
  Future<Result<Decimal>> totalPlanned(
    DateRange months,
    EntryType type, {
    String? userId,
  });

  Future<Result<Decimal>> totalReconciled(
    DateRange months,
    EntryType type, {
    String? userId,
  });

  Future<Result<ReconciliationCounts>> reconciliationCounts(
    DateRange months,
    EntryType type, {
    String? userId,
  });

  /// Not reconciled entries due from today until today + [days].
  Future<Result<List<UpcomingEntry>>> upcomingEntries({
    required int days,
    String? userId,
  });
}
