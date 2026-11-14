import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/features/accounts/domain/repositories/accounts_repository.dart';

/// Loads the accounts and cards with their balance.
class GetAccountBalances {
  const GetAccountBalances(this._repository);

  final AccountsRepository _repository;

  Future<Result<List<AccountBalance>>> call({String? userId}) =>
      _repository.getBalances(userId: userId);
}
