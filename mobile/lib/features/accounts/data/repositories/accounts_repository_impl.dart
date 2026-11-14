import 'package:decimal/decimal.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/data/datasources/accounts_remote_data_source.dart';
import 'package:mobile/features/accounts/data/mappers/account_balance_mapper.dart';
import 'package:mobile/features/accounts/data/mappers/bank_account_mapper.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/accounts/domain/repositories/accounts_repository.dart';

class AccountsRepositoryImpl implements AccountsRepository {
  const AccountsRepositoryImpl(this._remote);

  final AccountsRemoteDataSource _remote;

  @override
  Future<Result<List<BankAccount>>> getAccounts() async =>
      (await _remote.getAccounts()).map(
        (dtos) => [for (final dto in dtos) dto.toEntity()],
      );

  @override
  Future<Result<List<AccountBalance>>> getBalances({String? userId}) async =>
      (await _remote.getBalances(userId: userId))
          .map((dtos) => [for (final dto in dtos) dto.toEntity()]);

  @override
  Future<Result<Decimal>> getTotalBalance({
    required AccountKind kind,
    String? userId,
  }) => _remote.getTotalBalance(kind: kind, userId: userId);

  @override
  Future<Result<void>> updateSettings(
    String accountId, {
    bool? outgoingTransfersAreIncome,
    String? bankCode,
  }) => _remote.updateSettings(
    accountId,
    outgoingTransfersAreIncome: outgoingTransfersAreIncome,
    bankCode: bankCode,
  );
}
