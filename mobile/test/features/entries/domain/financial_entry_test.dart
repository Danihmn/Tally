import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';

import '../../../support/entry_factory.dart';

void main() {
  final today = DateTime(2026, 11, 14);

  group('FinancialEntry.isOverdue', () {
    test('a_planned_entry_before_today_is_overdue', () {
      final entry = makeEntry(dueDate: DateTime(2026, 11, 13));

      expect(entry.isOverdue(today), isTrue);
    });

    test('an_entry_due_today_is_not_overdue', () {
      expect(makeEntry(dueDate: today).isOverdue(today), isFalse);
    });

    test('only_a_planned_entry_can_be_overdue', () {
      final past = DateTime(2026, 10);

      expect(
        makeEntry(
          dueDate: past,
          status: EntryStatus.reconciled,
        ).isOverdue(today),
        isFalse,
      );
      expect(
        makeEntry(
          dueDate: past,
          status: EntryStatus.cancelled,
        ).isOverdue(today),
        isFalse,
      );
    });

    test('an_entry_without_a_due_date_is_never_overdue', () {
      final entry = FinancialEntry(
        id: 'e',
        ownerId: 'm',
        accountId: null,
        description: 'x',
        category: null,
        type: EntryType.expenses,
        paymentType: null,
        amount: Decimal.one,
        referenceMonth: DateTime(2026, 11),
        dueDate: null,
        status: EntryStatus.planned,
        installmentNumber: null,
        installmentTotal: null,
        notes: null,
        createdAt: DateTime.utc(2026, 11),
      );

      expect(entry.isOverdue(today), isFalse);
    });
  });

  group('FinancialEntry', () {
    test('the_installment_label_needs_both_numbers', () {
      expect(
        makeEntry(installmentNumber: 2, installmentTotal: 5).installmentLabel,
        '2/5',
      );
      expect(makeEntry().installmentLabel, isNull);
      expect(makeEntry(installmentNumber: 2).installmentLabel, isNull);
    });

    test('the_type_says_if_it_is_a_revenue', () {
      expect(makeEntry(type: EntryType.revenues).isRevenue, isTrue);
      expect(makeEntry().isRevenue, isFalse);
    });
  });

  group('EntryFilters', () {
    test('no_filter_is_empty', () {
      expect(const EntryFilters().isEmpty, isTrue);
      expect(const EntryFilters().activeCount, 0);
    });

    test('every_filter_counts_once_in_the_order_of_the_chips', () {
      final filters = EntryFilters(
        accountId: 'a1',
        type: EntryType.revenues,
        paymentType: PaymentType.credit,
        dueFrom: DateTime(2026, 11),
        dueTo: DateTime(2026, 11, 30),
        minAmount: Decimal.parse('10'),
        maxAmount: Decimal.parse('99'),
      );

      expect(filters.activeKeys, EntryFilterKey.values);
      expect(filters.activeCount, 7);
    });

    test('removing_a_filter_keeps_the_others', () {
      const filters = EntryFilters(accountId: 'a1', type: EntryType.expenses);

      final without = filters.without(EntryFilterKey.account);

      expect(without.accountId, isNull);
      expect(without.type, EntryType.expenses);
      expect(without.without(EntryFilterKey.type).isEmpty, isTrue);
    });
  });
}
