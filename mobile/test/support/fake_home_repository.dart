import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/home/domain/entities/daily_amount.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/entry_type.dart';
import 'package:mobile/features/home/domain/entities/reconciliation_counts.dart';
import 'package:mobile/features/home/domain/entities/top_expense.dart';
import 'package:mobile/features/home/domain/entities/upcoming_entry.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

Decimal dec(String value) => Decimal.parse(value);

String _days(DateRange range) =>
    '${DateFormatter.toApiDate(range.from)}..${DateFormatter.toApiDate(range.to)}';

/// [HomeRepository] that answers with what the test sets and records every
/// call as text, for example `totalExpenses 2026-11-01..2026-11-12 user=m1`.
/// Set [totalExpensesGate] to hold the answer of `totalExpenses`.
class FakeHomeRepository implements HomeRepository {
  final List<String> calls = [];

  Result<Decimal> totalExpensesResult = Result.success(dec('1200.50'));

  /// Answers of `totalExpenses` for a given person. Others use the default.
  final Map<String, Result<Decimal>> totalExpensesByUser = {};
  Completer<Result<Decimal>>? totalExpensesGate;

  Result<Decimal> totalRevenuesResult = Result.success(dec('5000.00'));
  Result<Decimal> balanceResult = Result.success(dec('3799.50'));
  Result<Decimal> averageResult = Result.success(dec('100.00'));
  Result<List<DailyAmount>> dailyResult = Result.success([
    for (var day = 1; day <= 12; day++)
      DailyAmount(
        day: DateTime(2026, 11, day),
        amount: switch (day) {
          2 => dec('100.00'),
          5 => dec('250.50'),
          _ => Decimal.zero,
        },
      ),
  ]);
  Result<List<TopExpense>> topResult = Result.success([
    TopExpense(
      date: DateTime(2026, 11, 5),
      amount: dec('800.00'),
      description: 'Aluguel',
    ),
    TopExpense(
      date: DateTime(2026, 11, 2),
      amount: dec('150.00'),
      description: null,
    ),
  ]);
  Result<Decimal> plannedResult = Result.success(dec('3000.00'));
  Result<Decimal> reconciledResult = Result.success(dec('1800.00'));
  Result<ReconciliationCounts> expenseCountsResult = const Result.success(
    ReconciliationCounts(reconciled: 2, notReconciled: 1),
  );
  Result<ReconciliationCounts> revenueCountsResult = const Result.success(
    ReconciliationCounts(reconciled: 1, notReconciled: 1),
  );
  Result<List<UpcomingEntry>> upcomingResult = Result.success([
    UpcomingEntry(
      description: 'Internet',
      amount: dec('120.00'),
      isIncome: false,
      category: 'Moradia',
      dueDate: DateTime(2026, 11, 15),
    ),
    UpcomingEntry(
      description: 'Salário',
      amount: dec('5000.00'),
      isIncome: true,
      category: null,
      dueDate: DateTime(2026, 11, 20),
    ),
  ]);

  int callsTo(String name) => calls.where((c) => c.startsWith('$name ')).length;

  @override
  Future<Result<Decimal>> totalExpenses(DateRange range, {String? userId}) {
    calls.add('totalExpenses ${_days(range)} user=$userId');
    final gate = totalExpensesGate;
    if (gate != null) return gate.future;
    return Future.value(totalExpensesByUser[userId] ?? totalExpensesResult);
  }

  @override
  Future<Result<Decimal>> totalRevenues(DateRange range, {String? userId}) {
    calls.add('totalRevenues ${_days(range)} user=$userId');
    return Future.value(totalRevenuesResult);
  }

  @override
  Future<Result<Decimal>> balance(DateRange range, {String? userId}) {
    calls.add('balance ${_days(range)} user=$userId');
    return Future.value(balanceResult);
  }

  @override
  Future<Result<Decimal>> averageDailyExpenses(
    DateRange range, {
    String? userId,
  }) {
    calls.add('averageDailyExpenses ${_days(range)} user=$userId');
    return Future.value(averageResult);
  }

  @override
  Future<Result<List<DailyAmount>>> dailyExpenses(
    DateRange range, {
    String? userId,
  }) {
    calls.add('dailyExpenses ${_days(range)} user=$userId');
    return Future.value(dailyResult);
  }

  @override
  Future<Result<List<TopExpense>>> topExpenses(
    DateRange range, {
    required int limit,
    String? userId,
  }) {
    calls.add('topExpenses ${_days(range)} limit=$limit user=$userId');
    return Future.value(topResult);
  }

  @override
  Future<Result<Decimal>> totalPlanned(
    DateRange months,
    EntryType type, {
    String? userId,
  }) {
    calls.add('totalPlanned ${_days(months)} ${type.apiValue} user=$userId');
    return Future.value(plannedResult);
  }

  @override
  Future<Result<Decimal>> totalReconciled(
    DateRange months,
    EntryType type, {
    String? userId,
  }) {
    calls.add('totalReconciled ${_days(months)} ${type.apiValue} user=$userId');
    return Future.value(reconciledResult);
  }

  @override
  Future<Result<ReconciliationCounts>> reconciliationCounts(
    DateRange months,
    EntryType type, {
    String? userId,
  }) {
    calls.add(
      'reconciliationCounts ${_days(months)} ${type.apiValue} user=$userId',
    );
    return Future.value(
      type == EntryType.expenses ? expenseCountsResult : revenueCountsResult,
    );
  }

  @override
  Future<Result<List<UpcomingEntry>>> upcomingEntries({
    required int days,
    String? userId,
  }) {
    calls.add('upcomingEntries days=$days user=$userId');
    return Future.value(upcomingResult);
  }
}
