import 'package:decimal/decimal.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/viewmodels/entry_form.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';

/// The fields of the recurrence form that are typed (and so can be wrong).
enum RecurrenceFormField { owner, description, amount, dueDay }

/// Why a typed field was refused.
enum RecurrenceFormError { required, invalidAmount, invalidDay }

/// What the recurrence form became: the draft when everything is valid,
/// otherwise the errors of the fields that are not.
class RecurrenceFormResult {
  const RecurrenceFormResult({this.draft, this.errors = const {}});

  final RecurrenceDraft? draft;
  final Map<RecurrenceFormField, RecurrenceFormError> errors;

  bool get isValid => draft != null;
}

/// Checks what was typed in the recurrence form. The owner is required and
/// the day is a whole number from 1 to 31 (or empty). A plain function, so it
/// is tested without a screen.
RecurrenceFormResult validateRecurrenceForm({
  required String? ownerId,
  required String description,
  required EntryType type,
  required PaymentType? paymentType,
  required String category,
  required String amount,
  required String dueDay,
  required String notes,
}) {
  final errors = <RecurrenceFormField, RecurrenceFormError>{};

  if (ownerId == null) {
    errors[RecurrenceFormField.owner] = RecurrenceFormError.required;
  }

  final name = description.trim();
  if (name.isEmpty) {
    errors[RecurrenceFormField.description] = RecurrenceFormError.required;
  }

  Decimal? value;
  if (amount.trim().isEmpty) {
    errors[RecurrenceFormField.amount] = RecurrenceFormError.required;
  } else {
    value = parsePositiveAmount(amount);
    if (value == null) {
      errors[RecurrenceFormField.amount] = RecurrenceFormError.invalidAmount;
    }
  }

  int? day;
  final dayText = dueDay.trim();
  if (dayText.isNotEmpty) {
    day = int.tryParse(dayText);
    if (day == null || day < 1 || day > 31) {
      errors[RecurrenceFormField.dueDay] = RecurrenceFormError.invalidDay;
    }
  }

  if (errors.isNotEmpty || value == null || ownerId == null) {
    return RecurrenceFormResult(errors: errors);
  }
  return RecurrenceFormResult(
    draft: RecurrenceDraft(
      ownerId: ownerId,
      description: name,
      type: type,
      amount: value,
      paymentType: paymentType,
      dueDay: day,
      category: blankToNull(category),
      notes: blankToNull(notes),
    ),
  );
}
