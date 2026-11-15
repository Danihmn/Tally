import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/entries/domain/entities/entry_draft.dart';

extension EntryDraftJson on EntryDraft {
  /// The body of `POST` and `PATCH /financial-entries`. Every key is sent, so
  /// a field left empty is cleared on an edit (`null`).
  Map<String, dynamic> toJson() => {
    'description': description.trim(),
    'type': type.apiValue,
    'amount': amount.toStringAsFixed(2),
    // The API wants day 1 of the month.
    'reference_month': DateFormatter.toApiDate(
      DateTime(referenceMonth.year, referenceMonth.month),
    ),
    'payment_type': paymentType?.apiValue,
    'category': category,
    'due_date': dueDate == null ? null : DateFormatter.toApiDate(dueDate!),
    'bank_account_id': accountId,
    'installment_number': installmentNumber,
    'installment_total': installmentTotal,
    'notes': notes,
  };
}
