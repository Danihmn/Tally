import 'package:decimal/decimal.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/features/entries/domain/entities/entry_draft.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';

/// The fields of the entry form that are typed (and so can be wrong).
enum EntryFormField { description, amount, due, installments }

/// Why a typed field was refused.
enum EntryFormError {
  required,
  invalidAmount,
  invalidDate,
  invalidInstallments,
}

/// What the entry form became: the draft when everything is valid, otherwise
/// the errors of the fields that are not.
class EntryFormResult {
  const EntryFormResult({this.draft, this.errors = const {}});

  final EntryDraft? draft;
  final Map<EntryFormField, EntryFormError> errors;

  bool get isValid => draft != null;
}

/// The largest amount of installments the API accepts.
const maxInstallments = 999;

/// `null` for an empty text, otherwise the trimmed text.
String? blankToNull(String text) {
  final clean = text.trim();
  return clean.isEmpty ? null : clean;
}

/// Reads a money field typed like `1.500,00`. Returns `null` when it is empty,
/// not a number, zero, or has more than two decimals.
Decimal? parsePositiveAmount(String text) {
  final value = MoneyFormatter.parse(text);
  if (value == null || value <= Decimal.zero) return null;
  if (value.round(scale: 2) != value) return null;
  return value;
}

/// Checks what was typed in the entry form: the amount like `10,50`, the
/// due date as `dd/mm/aaaa` and the installments as two whole numbers. It is a
/// plain function so it can be tested without a screen.
EntryFormResult validateEntryForm({
  required String description,
  required EntryType type,
  required PaymentType? paymentType,
  required String category,
  required String amount,
  required DateTime referenceMonth,
  required String due,
  required String? accountId,
  required String installmentCurrent,
  required String installmentTotal,
  required String notes,
}) {
  final errors = <EntryFormField, EntryFormError>{};

  final name = description.trim();
  if (name.isEmpty) {
    errors[EntryFormField.description] = EntryFormError.required;
  }

  Decimal? value;
  if (amount.trim().isEmpty) {
    errors[EntryFormField.amount] = EntryFormError.required;
  } else {
    value = parsePositiveAmount(amount);
    if (value == null) {
      errors[EntryFormField.amount] = EntryFormError.invalidAmount;
    }
  }

  DateTime? dueDate;
  if (due.trim().isNotEmpty) {
    dueDate = DateFormatter.parse(due.trim());
    if (dueDate == null) {
      errors[EntryFormField.due] = EntryFormError.invalidDate;
    }
  }

  int? current;
  int? total;
  final currentText = installmentCurrent.trim();
  final totalText = installmentTotal.trim();
  if (currentText.isNotEmpty || totalText.isNotEmpty) {
    current = int.tryParse(currentText);
    total = int.tryParse(totalText);
    final valid =
        current != null &&
        total != null &&
        current >= 1 &&
        total <= maxInstallments &&
        current <= total;
    if (!valid) {
      errors[EntryFormField.installments] = EntryFormError.invalidInstallments;
    }
  }

  if (errors.isNotEmpty || value == null) {
    return EntryFormResult(errors: errors);
  }
  return EntryFormResult(
    draft: EntryDraft(
      description: name,
      type: type,
      amount: value,
      referenceMonth: DateTime(referenceMonth.year, referenceMonth.month),
      paymentType: paymentType,
      category: blankToNull(category),
      dueDate: dueDate,
      accountId: accountId,
      installmentNumber: current,
      installmentTotal: total,
      notes: blankToNull(notes),
    ),
  );
}
