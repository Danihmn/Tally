import 'package:equatable/equatable.dart';

/// How many entries are reconciled and how many are not.
class ReconciliationCounts extends Equatable {
  const ReconciliationCounts({
    required this.reconciled,
    required this.notReconciled,
  });

  final int reconciled;
  final int notReconciled;

  @override
  List<Object?> get props => [reconciled, notReconciled];
}
