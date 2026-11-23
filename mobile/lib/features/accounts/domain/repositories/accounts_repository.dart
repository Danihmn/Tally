import 'package:decimal/decimal.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/accounts/domain/entities/card_bill.dart';

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

  /// Changes the "conta salário" settings of a bank account. Turning the
  /// flag on needs a [bankCode] (sent now or already stored).
  Future<Result<void>> updateSettings(
    String accountId, {
    bool? outgoingTransfersAreIncome,
    String? bankCode,
  });

  /// The bill of a credit card that is due in [month] (any day of it): only
  /// the installment of that month counts for an installment purchase.
  Future<Result<CardBill>> getCardBill(
    String accountId, {
    required DateTime month,
  });
}
