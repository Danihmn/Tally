import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// Whether the entry is money to receive or money to pay.
enum EntryType {
  revenues('REVENUES'),
  expenses('EXPENSES');

  const EntryType(this.apiValue);

  /// What the API sends and expects in the `type` field.
  final String apiValue;
}

/// How the entry is paid.
enum PaymentType {
  debit('DEBIT'),
  credit('CREDIT');

  const PaymentType(this.apiValue);

  final String apiValue;
}

/// Where the entry is in its life: waiting for a bank transaction, matched
/// with one, or cancelled.
enum EntryStatus {
  planned('PLANNED'),
  reconciled('RECONCILED'),
  cancelled('CANCELLED');

  const EntryStatus(this.apiValue);

  final String apiValue;
}

/// A planned entry (lançamento): something the house plans to pay or receive.
class FinancialEntry extends Equatable {
  const FinancialEntry({
    required this.id,
    required this.ownerId,
    required this.accountId,
    required this.description,
    required this.category,
    required this.type,
    required this.paymentType,
    required this.amount,
    required this.referenceMonth,
    required this.dueDate,
    required this.status,
    required this.installmentNumber,
    required this.installmentTotal,
    required this.notes,
    required this.createdAt,
  });

  final String id;

  /// The person the entry belongs to.
  final String ownerId;

  /// The account or card it is paid with, when the entry says it.
  final String? accountId;
  final String description;

  /// Free text as it was written. It may be missing.
  final String? category;
  final EntryType type;
  final PaymentType? paymentType;

  /// Always positive: the direction is [type].
  final Decimal amount;

  /// The first day of the month the entry belongs to.
  final DateTime referenceMonth;
  final DateTime? dueDate;
  final EntryStatus status;
  final int? installmentNumber;
  final int? installmentTotal;
  final String? notes;
  final DateTime createdAt;

  bool get isRevenue => type == EntryType.revenues;

  /// "2/5" for the second of five installments, `null` when not in parts.
  String? get installmentLabel {
    final number = installmentNumber;
    final total = installmentTotal;
    return number == null || total == null ? null : '$number/$total';
  }

  /// Planned and past its due date. [today] is the local day, at midnight.
  bool isOverdue(DateTime today) {
    final due = dueDate;
    return status == EntryStatus.planned && due != null && due.isBefore(today);
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    accountId,
    description,
    category,
    type,
    paymentType,
    amount,
    referenceMonth,
    dueDate,
    status,
    installmentNumber,
    installmentTotal,
    notes,
    createdAt,
  ];
}
