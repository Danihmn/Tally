import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/accounts/data/datasources/accounts_remote_data_source.dart';
import 'package:mobile/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:mobile/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:mobile/features/accounts/domain/usecases/get_account_balances.dart';
import 'package:mobile/features/accounts/domain/usecases/get_bank_accounts.dart';
import 'package:mobile/features/accounts/domain/usecases/get_total_balance.dart';
import 'package:mobile/features/accounts/domain/usecases/update_account_settings.dart';
import 'package:mobile/features/accounts/presentation/viewmodels/accounts_view_model.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

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
    )
    ..registerLazySingleton<GetAccountBalances>(
      () => GetAccountBalances(container<AccountsRepository>()),
    )
    ..registerLazySingleton<GetTotalBalance>(
      () => GetTotalBalance(container<AccountsRepository>()),
    )
    ..registerLazySingleton<UpdateAccountSettings>(
      () => UpdateAccountSettings(container<AccountsRepository>()),
    )
    ..registerFactory<AccountsViewModel>(
      () => AccountsViewModel(
        scopeController: container<HouseholdScopeController>(),
        getBalances: container<GetAccountBalances>(),
        getTotal: container<GetTotalBalance>(),
        updateSettings: container<UpdateAccountSettings>(),
      ),
    );
}
