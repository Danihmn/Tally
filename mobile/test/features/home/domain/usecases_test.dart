import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/reconciliation_counts.dart';
import 'package:mobile/features/home/domain/usecases/get_planning_progress.dart';
import 'package:mobile/features/home/domain/usecases/get_spending_by_member.dart';
import 'package:mobile/features/home/domain/usecases/get_spending_summary.dart';
import 'package:mobile/features/home/domain/usecases/get_top_expenses.dart';
import 'package:mobile/features/home/domain/usecases/get_upcoming_entries.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

import '../../../support/fake_home_repository.dart';

void main() {
  late FakeHomeRepository repository;
  final range = DateRange(from: DateTime(2026, 11), to: DateTime(2026, 11, 12));

  setUp(() => repository = FakeHomeRepository());

  group('GetSpendingSummary', () {
    test('puts_the_four_numbers_together', () async {
      final result = await GetSpendingSummary(repository)(range, userId: 'm1');

      final summary = result.valueOrNull!;
      expect(summary.spent, dec('1200.50'));
      expect(summary.received, dec('5000.00'));
      expect(summary.balance, dec('3799.50'));
      expect(summary.averagePerDay, dec('100.00'));
    });

    test('asks_the_four_endpoints_for_the_same_period_and_person', () async {
      await GetSpendingSummary(repository)(range, userId: 'm1');

      expect(repository.calls, hasLength(4));
      expect(
        repository.calls,
        everyElement(contains('2026-11-01..2026-11-12 user=m1')),
      );
    });

    test('one_failure_fails_the_whole_summary', () async {
      repository.balanceResult = const Result.failure(NetworkFailure());

      final result = await GetSpendingSummary(repository)(range);

      expect(result.failureOrNull, const NetworkFailure());
    });
  });

  group('GetPlanningProgress', () {
    test('the_amounts_are_of_the_expenses', () async {
      final result = await GetPlanningProgress(repository)(range);

      final progress = result.valueOrNull!;
      expect(progress.planned, dec('3000.00'));
      expect(progress.reconciled, dec('1800.00'));
      expect(repository.calls.where((c) => c.startsWith('totalPlanned')), [
        'totalPlanned 2026-11-01..2026-11-12 EXPENSES user=null',
      ]);
    });

    test('the_counts_add_the_expenses_and_the_revenues', () async {
      final result = await GetPlanningProgress(repository)(range);

      final progress = result.valueOrNull!;
      expect(progress.reconciledCount, 3); // 2 expenses + 1 revenue
      expect(progress.notReconciledCount, 2); // 1 expense + 1 revenue
      expect(progress.totalCount, 5);
    });

    test('a_failure_in_any_call_is_the_failure_of_the_card', () async {
      repository.revenueCountsResult =
          const Result<ReconciliationCounts>.failure(
            ServerUnavailableFailure(),
          );

      final result = await GetPlanningProgress(repository)(range);

      expect(result.failureOrNull, const ServerUnavailableFailure());
    });
  });

  group('GetSpendingByMember', () {
    const ana = Member(id: 'm1', firstName: 'Ana', householdId: 'h');
    const bia = Member(id: 'm2', firstName: 'Bia', householdId: 'h');

    test('asks_the_spending_of_each_person', () async {
      await GetSpendingByMember(repository)(range, [ana, bia]);

      expect(repository.calls, [
        'totalExpenses 2026-11-01..2026-11-12 user=m1',
        'totalExpenses 2026-11-01..2026-11-12 user=m2',
      ]);
    });

    test('the_person_who_spent_more_comes_first', () async {
      repository.totalExpensesByUser['m1'] = Result.success(dec('100.00'));
      repository.totalExpensesByUser['m2'] = Result.success(dec('300.00'));

      final result = await GetSpendingByMember(repository)(range, [ana, bia]);

      expect(result.valueOrNull!.items.map((i) => i.member), [bia, ana]);
    });

    test('a_tie_keeps_the_order_of_the_list', () async {
      final result = await GetSpendingByMember(repository)(range, [ana, bia]);

      expect(result.valueOrNull!.items.map((i) => i.member), [ana, bia]);
    });

    test('a_failure_for_one_person_fails_the_card', () async {
      repository.totalExpensesByUser['m2'] = const Result.failure(
        TimeoutFailure(),
      );

      final result = await GetSpendingByMember(repository)(range, [ana, bia]);

      expect(result.failureOrNull, const TimeoutFailure());
    });
  });

  group('defaults', () {
    test('the_top_expenses_are_five_by_default', () async {
      await GetTopExpenses(repository)(range);

      expect(repository.calls.single, contains('limit=5'));
    });

    test('the_top_expenses_limit_can_be_changed', () async {
      await GetTopExpenses(repository)(range, limit: 10);

      expect(repository.calls.single, contains('limit=10'));
    });

    test('the_upcoming_entries_look_thirty_days_ahead', () async {
      await GetUpcomingEntries(repository)(userId: 'm1');

      expect(repository.calls.single, 'upcomingEntries days=30 user=m1');
    });
  });
}
