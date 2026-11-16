import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/recurrences/presentation/viewmodels/recurrence_form.dart';

RecurrenceFormResult validate({
  String? ownerId = 'm2',
  String description = 'Aluguel',
  EntryType type = EntryType.expenses,
  PaymentType? paymentType,
  String category = '',
  String amount = '1.500,00',
  String dueDay = '',
  String notes = '',
}) => validateRecurrenceForm(
  ownerId: ownerId,
  description: description,
  type: type,
  paymentType: paymentType,
  category: category,
  amount: amount,
  dueDay: dueDay,
  notes: notes,
);

void main() {
  group('validateRecurrenceForm', () {
    test('a_minimal_form_becomes_a_draft_without_a_fixed_day', () {
      final draft = validate().draft!;

      expect(draft.ownerId, 'm2');
      expect(draft.description, 'Aluguel');
      expect(draft.amount, Decimal.parse('1500'));
      expect(draft.dueDay, isNull);
      expect(draft.category, isNull);
      expect(draft.notes, isNull);
    });

    test('every_field_is_read_and_trimmed', () {
      final draft = validate(
        description: ' Salário ',
        type: EntryType.revenues,
        paymentType: PaymentType.credit,
        category: ' Renda ',
        amount: '5000',
        dueDay: '31',
        notes: ' ok ',
      ).draft!;

      expect(draft.description, 'Salário');
      expect(draft.type, EntryType.revenues);
      expect(draft.paymentType, PaymentType.credit);
      expect(draft.category, 'Renda');
      expect(draft.dueDay, 31);
      expect(draft.notes, 'ok');
    });

    test('the_description_and_the_amount_are_required', () {
      final result = validate(description: ' ', amount: '');

      expect(result.isValid, isFalse);
      expect(result.errors, {
        RecurrenceFormField.description: RecurrenceFormError.required,
        RecurrenceFormField.amount: RecurrenceFormError.required,
      });
    });

    test('the_owner_is_required', () {
      final result = validate(ownerId: null);

      expect(result.isValid, isFalse);
      expect(result.errors, {
        RecurrenceFormField.owner: RecurrenceFormError.required,
      });
    });

    test('the_amount_must_be_positive', () {
      expect(
        validate(amount: '0').errors[RecurrenceFormField.amount],
        RecurrenceFormError.invalidAmount,
      );
    });

    test('the_day_is_a_whole_number_from_1_to_31', () {
      for (final text in ['0', '32', 'x', '-1']) {
        expect(
          validate(dueDay: text).errors[RecurrenceFormField.dueDay],
          RecurrenceFormError.invalidDay,
          reason: text,
        );
      }
      for (final text in ['1', '29', '31']) {
        expect(validate(dueDay: text).isValid, isTrue, reason: text);
      }
    });
  });
}
