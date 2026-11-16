import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/accounts/domain/usecases/get_bank_accounts.dart';
import 'package:mobile/features/entries/domain/usecases/search_entries.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/transactions/data/datasources/transactions_remote_data_source.dart';
import 'package:mobile/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:mobile/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:mobile/features/transactions/domain/transactions_filter_request.dart';
import 'package:mobile/features/transactions/domain/usecases/link_transaction_entry.dart';
import 'package:mobile/features/transactions/domain/usecases/search_transactions.dart';
import 'package:mobile/features/transactions/domain/usecases/unlink_transaction_entry.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/linked_entries_view_model.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/transactions_view_model.dart';

/// Registers the transactions feature.
void registerTransactionsDependencies(GetIt container) {
  container
    ..registerLazySingleton<TransactionsRemoteDataSource>(
      () => TransactionsRemoteDataSource(container<Dio>()),
    )
    ..registerLazySingleton<TransactionsRepository>(
      () =>
          TransactionsRepositoryImpl(container<TransactionsRemoteDataSource>()),
    )
    ..registerLazySingleton<SearchTransactions>(
      () => SearchTransactions(container<TransactionsRepository>()),
    )
    ..registerLazySingleton<LinkTransactionEntry>(
      () => LinkTransactionEntry(container<TransactionsRepository>()),
    )
    ..registerLazySingleton<UnlinkTransactionEntry>(
      () => UnlinkTransactionEntry(container<TransactionsRepository>()),
    )
    ..registerLazySingleton<TransactionsFilterRequest>(
      TransactionsFilterRequest.new,
      dispose: (request) => request.dispose(),
    )
    ..registerFactory<TransactionsViewModel>(
      () => TransactionsViewModel(
        scopeController: container<HouseholdScopeController>(),
        searchTransactions: container<SearchTransactions>(),
        getAccounts: container<GetBankAccounts>(),
        filterRequest: container<TransactionsFilterRequest>(),
      ),
    )
    ..registerFactoryParam<LinkedEntriesViewModel, String, void>(
      (transactionId, _) => LinkedEntriesViewModel(
        transactionId: transactionId,
        searchEntries: container<SearchEntries>(),
        linkEntry: container<LinkTransactionEntry>(),
        unlinkEntry: container<UnlinkTransactionEntry>(),
        getAccounts: container<GetBankAccounts>(),
        scopeController: container<HouseholdScopeController>(),
      ),
    );
}
