import 'package:decimal/decimal.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';

/// The bank accounts and credit cards of the house.
abstract interface class AccountsRepository {
  /// Every account of the house, whoever connected it.
  Future<Result<List<BankAccount>>> getAccounts();

  /// The accounts and cards of connected banks with their balance. [userId]
  /// limits it to one person (without it, the whole house).
  Future<Result<List<AccountBalance>>> getBalances({String? userId});

  /// The sum of the balances of one kind (accounts, or the bills of the cards).
  Future<Result<Decimal>> getTotalBalance({
    required AccountKind kind,
    String? userId,
  });
}
