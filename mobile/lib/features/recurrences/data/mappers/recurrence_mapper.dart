import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/recurrences/data/models/recurrence_dto.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';

extension RecurrenceDtoMapper on RecurrenceDto {
  Recurrence toEntity() => Recurrence(
    id: id,
    description: description,
    type: type == EntryType.revenues.apiValue
        ? EntryType.revenues
        : EntryType.expenses,
    paymentType: switch (paymentType) {
      final String value when value == PaymentType.debit.apiValue =>
        PaymentType.debit,
      final String value when value == PaymentType.credit.apiValue =>
        PaymentType.credit,
      _ => null,
    },
    amount: amount,
    dueDay: dueDay,
    category: category,
    notes: notes,
    ownerId: userId,
    status: status == RecurrenceStatus.cancelled.apiValue
        ? RecurrenceStatus.cancelled
        : RecurrenceStatus.active,
  );
}

extension ProvisionResultDtoMapper on ProvisionResultDto {
  ProvisionResult toEntity() => ProvisionResult(
    referenceMonth: referenceMonth,
    created: created,
    skipped: skipped,
  );
}

extension RecurrenceDraftJson on RecurrenceDraft {
  /// The body of `POST` and `PATCH /recurrences`. Every key is sent, so a
  /// field left empty is cleared on an edit (`null`).
  Map<String, dynamic> toJson() => {
    'user_id': ownerId,
    'description': description.trim(),
    'type': type.apiValue,
    'amount': amount.toStringAsFixed(2),
    'payment_type': paymentType?.apiValue,
    'due_day': dueDay,
    'category': category,
    'notes': notes,
  };
}
