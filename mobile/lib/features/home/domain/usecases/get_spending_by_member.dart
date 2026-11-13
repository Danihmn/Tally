import 'package:decimal/decimal.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/spending_by_member.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

/// What each person of the house spent in a period, the biggest first.
class GetSpendingByMember {
  const GetSpendingByMember(this._repository);

  final HomeRepository _repository;

  Future<Result<SpendingByMember>> call(
    DateRange range,
    List<Member> members,
  ) async {
    final results = await Future.wait([
      for (final member in members)
        _repository.totalExpenses(range, userId: member.id),
    ]);

    final items = <MemberSpending>[];
    for (var i = 0; i < members.length; i++) {
      final failure = results[i].failureOrNull;
      if (failure != null) return Result.failure(failure);
      final Decimal amount = results[i].valueOrNull!;
      items.add(MemberSpending(member: members[i], amount: amount));
    }
    // A stable sort: people with the same amount keep the order of the list.
    final sorted = [...items]..sort((a, b) => b.amount.compareTo(a.amount));
    return Result.success(SpendingByMember(sorted));
  }
}
