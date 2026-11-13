import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// What was spent in one day. Zero when nothing was spent.
class DailyAmount extends Equatable {
  const DailyAmount({required this.day, required this.amount});

  final DateTime day;
  final Decimal amount;

  @override
  List<Object?> get props => [day, amount];
}
