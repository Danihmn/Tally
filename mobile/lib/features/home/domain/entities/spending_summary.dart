import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// The four numbers on top of the home, for one period.
class SpendingSummary extends Equatable {
  const SpendingSummary({
    required this.spent,
    required this.received,
    required this.balance,
    required this.averagePerDay,
  });

  /// A period with nothing in it.
  factory SpendingSummary.zero() => SpendingSummary(
    spent: Decimal.zero,
    received: Decimal.zero,
    balance: Decimal.zero,
    averagePerDay: Decimal.zero,
  );

  final Decimal spent;
  final Decimal received;

  /// Received minus spent. Negative when more was spent than received.
  final Decimal balance;
  final Decimal averagePerDay;

  bool get hasSpending => spent > Decimal.zero;

  @override
  List<Object?> get props => [spent, received, balance, averagePerDay];
}
