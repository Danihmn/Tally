import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/accounts/domain/usecases/get_bank_accounts.dart';
import 'package:mobile/features/entries/data/datasources/entries_remote_data_source.dart';
import 'package:mobile/features/entries/data/repositories/entries_repository_impl.dart';
import 'package:mobile/features/entries/domain/repositories/entries_repository.dart';
import 'package:mobile/features/entries/domain/usecases/search_entries.dart';
import 'package:mobile/features/entries/presentation/viewmodels/entries_view_model.dart';
import 'package:mobile/features/entries/presentation/viewmodels/linked_transactions_view_model.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/transactions/domain/usecases/search_transactions.dart';

/// Registers the entries feature.
void registerEntriesDependencies(GetIt container) {
  container
    ..registerLazySingleton<EntriesRemoteDataSource>(
      () => EntriesRemoteDataSource(container<Dio>()),
    )
    ..registerLazySingleton<EntriesRepository>(
      () => EntriesRepositoryImpl(container<EntriesRemoteDataSource>()),
    )
    ..registerLazySingleton<SearchEntries>(
      () => SearchEntries(container<EntriesRepository>()),
    )
    ..registerFactory<EntriesViewModel>(
      () => EntriesViewModel(
        scopeController: container<HouseholdScopeController>(),
        searchEntries: container<SearchEntries>(),
        getAccounts: container<GetBankAccounts>(),
      ),
    )
    ..registerFactoryParam<LinkedTransactionsViewModel, String, void>(
      (entryId, _) => LinkedTransactionsViewModel(
        entryId: entryId,
        searchTransactions: container<SearchTransactions>(),
        getAccounts: container<GetBankAccounts>(),
        scopeController: container<HouseholdScopeController>(),
      ),
    );
}
