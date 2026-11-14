import 'package:decimal/decimal.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';

/// An entry with safe values. Pass only what the test cares about.
FinancialEntry makeEntry({
  String id = 'e1',
  String ownerId = 'm1',
  String? accountId = 'a1',
  String description = 'Aluguel',
  String? category = 'Moradia',
  EntryType type = EntryType.expenses,
  PaymentType? paymentType = PaymentType.debit,
  String amount = '1500.00',
  DateTime? referenceMonth,
  DateTime? dueDate,
  EntryStatus status = EntryStatus.planned,
  int? installmentNumber,
  int? installmentTotal,
  String? notes,
}) => FinancialEntry(
  id: id,
  ownerId: ownerId,
  accountId: accountId,
  description: description,
  category: category,
  type: type,
  paymentType: paymentType,
  amount: Decimal.parse(amount),
  referenceMonth: referenceMonth ?? DateTime(2026, 11),
  dueDate: dueDate ?? DateTime(2026, 11, 20),
  status: status,
  installmentNumber: installmentNumber,
  installmentTotal: installmentTotal,
  notes: notes,
  createdAt: DateTime.utc(2026, 11, 1, 9),
);
