import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/data/datasources/accounts_remote_data_source.dart';
import 'package:mobile/features/accounts/data/mappers/bank_account_mapper.dart';
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
}
