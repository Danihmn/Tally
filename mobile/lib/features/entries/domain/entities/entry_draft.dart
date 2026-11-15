import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';

/// What the person fills in the entry form, to create an entry or to replace
/// the editable data of one. The optional fields are `null` when left empty:
/// on an edit that clears them.
class EntryDraft extends Equatable {
  const EntryDraft({
    required this.description,
    required this.type,
    required this.amount,
    required this.referenceMonth,
    this.paymentType,
    this.category,
    this.dueDate,
    this.accountId,
    this.installmentNumber,
    this.installmentTotal,
    this.notes,
  });

  /// The draft that has the same data as [entry], to start an edit.
  factory EntryDraft.fromEntry(FinancialEntry entry) => EntryDraft(
    description: entry.description,
    type: entry.type,
    amount: entry.amount,
    referenceMonth: entry.referenceMonth,
    paymentType: entry.paymentType,
    category: entry.category,
    dueDate: entry.dueDate,
    accountId: entry.accountId,
    installmentNumber: entry.installmentNumber,
    installmentTotal: entry.installmentTotal,
    notes: entry.notes,
  );

  final String description;
  final EntryType type;

  /// Always positive: the direction is [type].
  final Decimal amount;

  /// The first day of the month the entry belongs to.
  final DateTime referenceMonth;
  final PaymentType? paymentType;
  final String? category;
  final DateTime? dueDate;
  final String? accountId;
  final int? installmentNumber;
  final int? installmentTotal;
  final String? notes;

  @override
  List<Object?> get props => [
    description,
    type,
    amount,
    referenceMonth,
    paymentType,
    category,
    dueDate,
    accountId,
    installmentNumber,
    installmentTotal,
    notes,
  ];
}
