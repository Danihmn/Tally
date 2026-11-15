import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/viewmodels/entry_form.dart';

EntryFormResult validate({
  String description = 'Aluguel',
  EntryType type = EntryType.expenses,
  PaymentType? paymentType,
  String category = '',
  String amount = '1.500,00',
  DateTime? month,
  String due = '',
  String? accountId,
  String current = '',
  String total = '',
  String notes = '',
}) => validateEntryForm(
  description: description,
  type: type,
  paymentType: paymentType,
  category: category,
  amount: amount,
  referenceMonth: month ?? DateTime(2026, 12, 20),
  due: due,
  accountId: accountId,
  installmentCurrent: current,
  installmentTotal: total,
  notes: notes,
);

void main() {
  group('validateEntryForm', () {
    test('a_minimal_form_becomes_a_draft_with_empty_optionals_as_null', () {
      final result = validate();

      final draft = result.draft!;
      expect(result.isValid, isTrue);
      expect(draft.description, 'Aluguel');
      expect(draft.amount, Decimal.parse('1500'));
      expect(draft.referenceMonth, DateTime(2026, 12));
      expect(draft.category, isNull);
      expect(draft.dueDate, isNull);
      expect(draft.installmentNumber, isNull);
      expect(draft.notes, isNull);
      expect(draft.paymentType, isNull);
    });

    test('every_field_is_read_and_trimmed', () {
      final draft = validate(
        description: '  Luz  ',
        type: EntryType.revenues,
        paymentType: PaymentType.credit,
        category: ' Moradia ',
        amount: '10,5',
        due: '05/12/2026',
        accountId: 'a1',
        current: '2',
        total: '5',
        notes: ' ok ',
      ).draft!;

      expect(draft.description, 'Luz');
      expect(draft.type, EntryType.revenues);
      expect(draft.paymentType, PaymentType.credit);
      expect(draft.category, 'Moradia');
      expect(draft.amount, Decimal.parse('10.5'));
      expect(draft.dueDate, DateTime(2026, 12, 5));
      expect(draft.accountId, 'a1');
      expect((draft.installmentNumber, draft.installmentTotal), (2, 5));
      expect(draft.notes, 'ok');
    });

    test('the_description_and_the_amount_are_required', () {
      final result = validate(description: '  ', amount: '');

      expect(result.isValid, isFalse);
      expect(result.errors, {
        EntryFormField.description: EntryFormError.required,
        EntryFormField.amount: EntryFormError.required,
      });
    });

    test('the_amount_must_be_a_positive_number_with_two_decimals_at_most', () {
      for (final text in ['0', '0,00', 'abc', '-5', '10,123']) {
        expect(
          validate(amount: text).errors[EntryFormField.amount],
          EntryFormError.invalidAmount,
          reason: text,
        );
      }
    });

    test('an_invalid_due_date_is_refused_and_an_empty_one_is_fine', () {
      expect(
        validate(due: '31/02/2026').errors[EntryFormField.due],
        EntryFormError.invalidDate,
      );
      expect(validate(due: '').isValid, isTrue);
    });

    test(
      'installments_come_together_and_the_current_cannot_pass_the_total',
      () {
        for (final pair in [
          ('2', ''),
          ('', '5'),
          ('6', '5'),
          ('0', '5'),
          ('a', '5'),
          ('1', '1000'),
        ]) {
          expect(
            validate(
              current: pair.$1,
              total: pair.$2,
            ).errors[EntryFormField.installments],
            EntryFormError.invalidInstallments,
            reason: '$pair',
          );
        }
        expect(validate(current: '5', total: '5').isValid, isTrue);
      },
    );
  });

  group('parsePositiveAmount', () {
    test('reads_brazilian_text_and_refuses_zero_or_too_many_decimals', () {
      expect(parsePositiveAmount('1.234,56'), Decimal.parse('1234.56'));
      expect(parsePositiveAmount('7'), Decimal.parse('7'));
      expect(parsePositiveAmount('0'), isNull);
      expect(parsePositiveAmount('1,234'), isNull);
      expect(parsePositiveAmount(''), isNull);
    });
  });
}
