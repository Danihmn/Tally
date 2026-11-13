import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';

/// The bank accounts and credit cards of the house.
abstract interface class AccountsRepository {
  /// Every account of the house, whoever connected it.
  Future<Result<List<BankAccount>>> getAccounts();
}
