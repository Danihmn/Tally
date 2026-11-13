import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';

/// The transactions of one day, with what the day added up to.
class TransactionDayGroup extends Equatable {
  const TransactionDayGroup({required this.day, required this.items});

  /// The UTC calendar day, at midnight.
  final DateTime day;
  final List<Transaction> items;

  /// Money in minus money out. Only of the items that are here: while the next
  /// page is not loaded, the last day can be incomplete.
  Decimal get total =>
      items.fold(Decimal.zero, (sum, item) => sum + item.signedAmount);

  @override
  List<Object?> get props => [day, items];
}

/// Groups a list that is already ordered by date (newest first) by day. Items
/// of the same day that are not side by side start a new group, so the order
/// of the list is never changed.
List<TransactionDayGroup> groupTransactionsByDay(
  List<Transaction> transactions,
) {
  final groups = <TransactionDayGroup>[];
  var currentDay = DateTime(0);
  var current = <Transaction>[];

  void close() {
    if (current.isNotEmpty) {
      groups.add(TransactionDayGroup(day: currentDay, items: current));
    }
  }

  for (final transaction in transactions) {
    if (current.isEmpty || transaction.day != currentDay) {
      close();
      currentDay = transaction.day;
      current = [];
    }
    current.add(transaction);
  }
  close();
  return groups;
}
