import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// One transaction inside a credit card bill. Each installment of a purchase
/// is its own transaction, so a purchase in 10x shows only the installment of
/// that bill.
class CardBillItem extends Equatable {
  const CardBillItem({
    required this.id,
    required this.day,
    required this.description,
    required this.amount,
    required this.isCredit,
    required this.isPending,
    this.installmentNumber,
    this.totalInstallments,
  });

  final String id;

  /// The day of the transaction (the API sends days at UTC midnight).
  final DateTime day;
  final String? description;

  /// Absolute value. The direction comes from [isCredit].
  final Decimal amount;

  /// A refund or credit on the card: it lowers the bill.
  final bool isCredit;

  /// The bill is still open at the bank.
  final bool isPending;
  final int? installmentNumber;
  final int? totalInstallments;

  /// `3/10` for an installment purchase, `null` for a single payment.
  String? get installmentLabel {
    final number = installmentNumber;
    final total = totalInstallments;
    if (number == null || total == null || total <= 1) return null;
    return '$number/$total';
  }

  @override
  List<Object?> get props => [
    id,
    day,
    description,
    amount,
    isCredit,
    isPending,
    installmentNumber,
    totalInstallments,
  ];
}

/// The bill of a credit card that is due in [month].
class CardBill extends Equatable {
  const CardBill({
    required this.accountId,
    required this.month,
    required this.total,
    required this.estimated,
    required this.items,
  });

  final String accountId;

  /// Day 1 of the due month (the month the bill is paid).
  final DateTime month;

  /// Purchases minus refunds. Payments of other bills are not in it.
  final Decimal total;

  /// The bank did not say the bill of some transaction, so it was estimated
  /// with the closing day of the card.
  final bool estimated;
  final List<CardBillItem> items;

  @override
  List<Object?> get props => [accountId, month, total, estimated, items];
}
