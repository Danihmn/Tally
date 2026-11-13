import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/accounts/domain/repositories/accounts_repository.dart';

/// Loads the accounts of the house.
class GetBankAccounts {
  const GetBankAccounts(this._repository);

  final AccountsRepository _repository;

  Future<Result<List<BankAccount>>> call() => _repository.getAccounts();
}
