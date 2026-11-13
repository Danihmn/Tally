import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/accounts/data/datasources/accounts_remote_data_source.dart';
import 'package:mobile/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:mobile/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:mobile/features/accounts/domain/usecases/get_bank_accounts.dart';

/// Registers the accounts feature.
void registerAccountsDependencies(GetIt container) {
  container
    ..registerLazySingleton<AccountsRemoteDataSource>(
      () => AccountsRemoteDataSource(container<Dio>()),
    )
    ..registerLazySingleton<AccountsRepository>(
      () => AccountsRepositoryImpl(container<AccountsRemoteDataSource>()),
    )
    ..registerLazySingleton<GetBankAccounts>(
      () => GetBankAccounts(container<AccountsRepository>()),
    );
}
