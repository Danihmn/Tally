import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

/// What one person of the house spent.
class MemberSpending extends Equatable {
  const MemberSpending({required this.member, required this.amount});

  final Member member;
  final Decimal amount;

  @override
  List<Object?> get props => [member, amount];
}

/// What each person spent, the biggest first.
class SpendingByMember extends Equatable {
  const SpendingByMember(this.items);

  final List<MemberSpending> items;

  Decimal get total =>
      items.fold(Decimal.zero, (sum, item) => sum + item.amount);

  /// The part of the total that [item] spent, from 0 to 1. Only for the size
  /// of a bar and a percentage.
  double shareOf(MemberSpending item) {
    final all = total;
    if (all <= Decimal.zero) return 0;
    return (item.amount / all).toDouble().clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [items];
}
