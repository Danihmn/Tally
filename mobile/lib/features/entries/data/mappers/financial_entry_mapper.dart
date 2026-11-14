import 'package:mobile/features/entries/data/models/financial_entry_dto.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';

extension FinancialEntryDtoMapper on FinancialEntryDto {
  FinancialEntry toEntity() => FinancialEntry(
    id: id,
    ownerId: userId,
    accountId: bankAccountId,
    description: description,
    category: category,
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
    referenceMonth: referenceMonth,
    dueDate: dueDate,
    status: switch (status) {
      final String value when value == EntryStatus.reconciled.apiValue =>
        EntryStatus.reconciled,
      final String value when value == EntryStatus.cancelled.apiValue =>
        EntryStatus.cancelled,
      _ => EntryStatus.planned,
    },
    installmentNumber: installmentNumber,
    installmentTotal: installmentTotal,
    notes: notes,
    createdAt: createdAt,
  );
}
