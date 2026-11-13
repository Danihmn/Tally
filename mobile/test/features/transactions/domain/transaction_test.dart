import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_day_group.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';

import '../../../support/transaction_factory.dart';

void main() {
  group('Transaction', () {
    test('the_direction_comes_from_the_type_not_from_the_sign', () {
      // On a credit card a purchase has a positive amount and is a debit.
      final purchase = makeTransaction(amount: '89.90');

      expect(purchase.isIncome, isFalse);
      expect(purchase.signedAmount, Decimal.parse('-89.90'));
    });

    test('a_credit_is_money_in_whatever_the_sign', () {
      final salary = makeTransaction(
        amount: '5000.00',
        direction: TransactionDirection.credit,
      );
      final refundSentNegative = makeTransaction(
        amount: '-20.00',
        direction: TransactionDirection.credit,
      );

      expect(salary.signedAmount, Decimal.parse('5000.00'));
      expect(refundSentNegative.signedAmount, Decimal.parse('20.00'));
      expect(refundSentNegative.absoluteAmount, Decimal.parse('20.00'));
    });

    test('pending_is_known_by_the_status', () {
      expect(makeTransaction().isPending, isFalse);
      expect(
        makeTransaction(status: TransactionStatus.pending).isPending,
        isTrue,
      );
    });

    test('the_day_is_the_utc_day_of_the_date', () {
      final midnight = makeTransaction(date: DateTime.utc(2026, 11, 5));
      final lateNight = makeTransaction(
        date: DateTime.utc(2026, 11, 5, 23, 59),
      );

      expect(midnight.day, DateTime(2026, 11, 5));
      expect(lateNight.day, DateTime(2026, 11, 5));
    });

    test('a_date_with_another_offset_is_read_in_utc', () {
      // 22:00 on the 4th at UTC-3 is 01:00 on the 5th in UTC.
      final date = DateTime.parse('2026-11-04T22:00:00-03:00');

      expect(makeTransaction(date: date).day, DateTime(2026, 11, 5));
    });
  });

  group('groupTransactionsByDay', () {
    Transaction at(
      int day, {
      String id = 't',
      String amount = '-10.00',
      TransactionDirection direction = TransactionDirection.debit,
    }) => makeTransaction(
      id: '$id$day',
      date: DateTime.utc(2026, 11, day, 12),
      amount: amount,
      direction: direction,
    );

    test('an_empty_list_has_no_groups', () {
      expect(groupTransactionsByDay(const []), isEmpty);
    });

    test('items_of_the_same_day_go_together_in_order', () {
      final groups = groupTransactionsByDay([
        at(5, id: 'a'),
        at(5, id: 'b'),
        at(4, id: 'c'),
      ]);

      expect(groups.map((g) => g.day), [
        DateTime(2026, 11, 5),
        DateTime(2026, 11, 4),
      ]);
      expect(groups.first.items.map((t) => t.id), ['a5', 'b5']);
      expect(groups.last.items.map((t) => t.id), ['c4']);
    });

    test('the_total_of_a_day_is_money_in_minus_money_out', () {
      final groups = groupTransactionsByDay([
        at(5, id: 'a', amount: '-30.00'),
        at(5, id: 'b', amount: '-20.50'),
        at(
          5,
          id: 'c',
          amount: '100.00',
          direction: TransactionDirection.credit,
        ),
      ]);

      expect(groups.single.total, Decimal.parse('49.50'));
    });

    test('a_card_purchase_with_a_positive_amount_is_still_money_out', () {
      final groups = groupTransactionsByDay([at(5, amount: '40.00')]);

      expect(groups.single.total, Decimal.parse('-40.00'));
    });

    test('the_order_of_the_list_is_never_changed', () {
      final groups = groupTransactionsByDay([
        at(5, id: 'a'),
        at(4, id: 'b'),
        at(5, id: 'c'),
      ]);

      expect(groups.map((g) => g.day.day), [5, 4, 5]);
    });

    test('a_day_is_the_utc_day_even_for_other_offsets', () {
      final a = makeTransaction(
        id: 'a',
        date: DateTime.utc(2026, 11, 5, 0, 30),
      );
      final b = makeTransaction(
        id: 'b',
        date: DateTime.utc(2026, 11, 4, 23, 30),
      );

      final groups = groupTransactionsByDay([a, b]);

      expect(groups, hasLength(2));
    });
  });

  group('TransactionFilters', () {
    final filters = TransactionFilters(
      accountId: 'a1',
      direction: TransactionDirection.debit,
      status: TransactionStatus.pending,
      dateFrom: DateTime(2026, 11, 1),
      dateTo: DateTime(2026, 11, 12),
      minAmount: Decimal.parse('10'),
      maxAmount: Decimal.parse('500'),
    );

    test('no_filters_means_empty_and_zero_active', () {
      const none = TransactionFilters();

      expect(none.isEmpty, isTrue);
      expect(none.activeCount, 0);
      expect(none.activeKeys, isEmpty);
    });

    test('every_filter_in_use_counts_once', () {
      expect(filters.activeCount, 7);
      expect(filters.isEmpty, isFalse);
    });

    test('the_keys_come_in_the_order_of_the_chips', () {
      expect(filters.activeKeys, [
        TransactionFilterKey.account,
        TransactionFilterKey.direction,
        TransactionFilterKey.status,
        TransactionFilterKey.dateFrom,
        TransactionFilterKey.dateTo,
        TransactionFilterKey.minAmount,
        TransactionFilterKey.maxAmount,
      ]);
    });

    test('removing_a_filter_keeps_the_others', () {
      for (final key in TransactionFilterKey.values) {
        final reduced = filters.without(key);

        expect(reduced.activeCount, 6, reason: '$key');
        expect(reduced.activeKeys, isNot(contains(key)), reason: '$key');
      }
    });

    test('removing_one_filter_does_not_change_the_original', () {
      filters.without(TransactionFilterKey.account);

      expect(filters.accountId, 'a1');
    });

    test('filters_with_the_same_values_are_equal', () {
      expect(
        const TransactionFilters(accountId: 'a1'),
        const TransactionFilters(accountId: 'a1'),
      );
      expect(
        const TransactionFilters(accountId: 'a1'),
        isNot(const TransactionFilters(accountId: 'a2')),
      );
    });
  });
}
