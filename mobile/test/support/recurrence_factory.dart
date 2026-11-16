import 'package:decimal/decimal.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';

/// A recurrence with safe values. Pass only what the test cares about.
Recurrence makeRecurrence({
  String id = 'r1',
  String description = 'Aluguel',
  EntryType type = EntryType.expenses,
  PaymentType? paymentType = PaymentType.debit,
  String amount = '1500.00',
  int? dueDay = 5,
  String? category = 'Moradia',
  String? notes,
  String? ownerId = 'm1',
  RecurrenceStatus status = RecurrenceStatus.active,
}) => Recurrence(
  id: id,
  description: description,
  type: type,
  paymentType: paymentType,
  amount: Decimal.parse(amount),
  dueDay: dueDay,
  category: category,
  notes: notes,
  ownerId: ownerId,
  status: status,
);
