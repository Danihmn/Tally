import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// One of the biggest expenses of a period.
class TopExpense extends Equatable {
  const TopExpense({
    required this.date,
    required this.amount,
    required this.description,
  });

  final DateTime date;
  final Decimal amount;

  /// The bank may send no description.
  final String? description;

  @override
  List<Object?> get props => [date, amount, description];
}
