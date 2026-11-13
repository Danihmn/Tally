import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/transactions/data/datasources/transactions_remote_data_source.dart';
import 'package:mobile/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:mobile/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:mobile/features/transactions/domain/usecases/search_transactions.dart';

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
    );
}
