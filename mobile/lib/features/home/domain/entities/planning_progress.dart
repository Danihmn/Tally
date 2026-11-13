import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// Planned against real: how much of what was planned is already matched with
/// a bank transaction.
class PlanningProgress extends Equatable {
  const PlanningProgress({
    required this.planned,
    required this.reconciled,
    required this.reconciledCount,
    required this.notReconciledCount,
  });

  /// Amount of the planned expenses (reconciled or not, never cancelled).
  final Decimal planned;

  /// Amount of the planned expenses already reconciled.
  final Decimal reconciled;

  /// Entries (revenues and expenses) already reconciled.
  final int reconciledCount;

  /// Entries (revenues and expenses) still waiting for a bank transaction.
  final int notReconciledCount;

  int get totalCount => reconciledCount + notReconciledCount;

  /// The part of [planned] that is reconciled, from 0 to 1. Only for the size
  /// of a bar: money is never calculated with it.
  double get ratio {
    if (planned <= Decimal.zero) return 0;
    return (reconciled / planned).toDouble().clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
    planned,
    reconciled,
    reconciledCount,
    notReconciledCount,
  ];
}
