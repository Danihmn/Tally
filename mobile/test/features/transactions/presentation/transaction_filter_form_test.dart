import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/transaction_filter_form.dart';

TransactionFilterFormResult check({
  String from = '',
  String to = '',
  String min = '',
  String max = '',
}) => validateTransactionFilterForm(from: from, to: to, min: min, max: max);

void main() {
  group('validateTransactionFilterForm', () {
    test('empty_fields_are_valid_and_mean_no_limit', () {
      final result = check();

      expect(result.isValid, isTrue);
      expect(result.dateFrom, isNull);
      expect(result.dateTo, isNull);
      expect(result.minAmount, isNull);
      expect(result.maxAmount, isNull);
    });

    test('blank_fields_count_as_empty', () {
      expect(check(from: '   ', min: '  ').isValid, isTrue);
    });

    test('reads_dates_and_amounts', () {
      final result = check(
        from: '01/11/2026',
        to: '12/11/2026',
        min: '10,50',
        max: '1.234,56',
      );

      expect(result.isValid, isTrue);
      expect(result.dateFrom, DateTime(2026, 11, 1));
      expect(result.dateTo, DateTime(2026, 11, 12));
      expect(result.minAmount, Decimal.parse('10.50'));
      expect(result.maxAmount, Decimal.parse('1234.56'));
    });

    test('a_date_that_does_not_exist_is_an_error', () {
      final result = check(from: '31/02/2026');

      expect(result.errors[FilterField.from], FilterError.invalidDate);
      expect(result.dateFrom, isNull);
    });

    test('an_incomplete_date_is_an_error', () {
      final result = check(to: '12/11');

      expect(result.errors[FilterField.to], FilterError.invalidDate);
    });

    test('an_amount_that_is_not_a_number_is_an_error', () {
      final result = check(min: 'abc', max: ',,');

      expect(result.errors[FilterField.min], FilterError.invalidAmount);
      expect(result.errors[FilterField.max], FilterError.invalidAmount);
    });

    test('a_start_after_the_end_is_an_error_on_the_end_field', () {
      final result = check(from: '12/11/2026', to: '01/11/2026');

      expect(result.isValid, isFalse);
      expect(result.errors, {FilterField.to: FilterError.datesOutOfOrder});
    });

    test('the_same_day_in_both_fields_is_fine', () {
      expect(check(from: '05/11/2026', to: '05/11/2026').isValid, isTrue);
    });

    test('a_minimum_above_the_maximum_is_an_error_on_the_maximum_field', () {
      final result = check(min: '50', max: '10');

      expect(result.errors, {FilterField.max: FilterError.amountsOutOfOrder});
    });

    test('equal_minimum_and_maximum_are_fine', () {
      expect(check(min: '10', max: '10,00').isValid, isTrue);
    });

    test('one_wrong_field_does_not_hide_the_valid_ones', () {
      final result = check(from: '01/11/2026', to: 'x', min: '5');

      expect(result.dateFrom, DateTime(2026, 11, 1));
      expect(result.minAmount, Decimal.parse('5'));
      expect(result.errors.keys, [FilterField.to]);
    });
  });
}
