import 'package:decimal/decimal.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/features/accounts/domain/repositories/accounts_repository.dart';

/// Loads the sum of the balances of the accounts, or of the open bills of the
/// cards.
class GetTotalBalance {
  const GetTotalBalance(this._repository);

  final AccountsRepository _repository;

  Future<Result<Decimal>> call({required AccountKind kind, String? userId}) =>
      _repository.getTotalBalance(kind: kind, userId: userId);
}
