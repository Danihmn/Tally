import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/domain/entities/planning_progress.dart';
import 'package:mobile/features/home/domain/entities/spending_by_member.dart';
import 'package:mobile/features/home/domain/entities/spending_summary.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

import '../../../support/fake_home_repository.dart';

void main() {
  group('SpendingSummary', () {
    test('has_spending_only_when_something_was_spent', () {
      expect(SpendingSummary.zero().hasSpending, isFalse);
      expect(
        SpendingSummary(
          spent: dec('0.01'),
          received: Decimal.zero,
          balance: dec('-0.01'),
          averagePerDay: Decimal.zero,
        ).hasSpending,
        isTrue,
      );
    });
  });

  group('PlanningProgress', () {
    PlanningProgress build({
      String planned = '1000.00',
      String reconciled = '250.00',
      int reconciledCount = 3,
      int notReconciledCount = 1,
    }) => PlanningProgress(
      planned: dec(planned),
      reconciled: dec(reconciled),
      reconciledCount: reconciledCount,
      notReconciledCount: notReconciledCount,
    );

    test('the_ratio_is_the_reconciled_part_of_the_planned_amount', () {
      expect(build().ratio, 0.25);
    });

    test('nothing_planned_means_an_empty_bar', () {
      expect(build(planned: '0', reconciled: '0').ratio, 0);
    });

    test('the_bar_never_goes_past_full', () {
      expect(build(planned: '100.00', reconciled: '150.00').ratio, 1);
    });

    test('the_total_is_the_two_counts_together', () {
      expect(build().totalCount, 4);
    });
  });

  group('SpendingByMember', () {
    const ana = Member(id: 'm1', firstName: 'Ana', householdId: 'h');
    const bia = Member(id: 'm2', firstName: 'Bia', householdId: 'h');
    final spending = SpendingByMember([
      MemberSpending(member: ana, amount: dec('300.00')),
      MemberSpending(member: bia, amount: dec('100.00')),
    ]);

    test('the_total_is_the_sum_of_everybody', () {
      expect(spending.total, dec('400.00'));
    });

    test('the_share_is_the_part_of_the_total', () {
      expect(spending.shareOf(spending.items[0]), 0.75);
      expect(spending.shareOf(spending.items[1]), 0.25);
    });

    test('nobody_spent_means_zero_share_and_no_division_by_zero', () {
      final empty = SpendingByMember([
        MemberSpending(member: ana, amount: Decimal.zero),
      ]);

      expect(empty.shareOf(empty.items.single), 0);
    });
  });
}
