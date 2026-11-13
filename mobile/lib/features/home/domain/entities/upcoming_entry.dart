import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// A planned entry that is due soon and not reconciled yet.
class UpcomingEntry extends Equatable {
  const UpcomingEntry({
    required this.description,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.dueDate,
  });

  final String description;
  final Decimal amount;

  /// True for money to receive, false for money to pay.
  final bool isIncome;

  /// The entry may have no category.
  final String? category;
  final DateTime dueDate;

  @override
  List<Object?> get props => [description, amount, isIncome, category, dueDate];
}
