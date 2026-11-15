import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/recurrences/data/datasources/recurrences_remote_data_source.dart';
import 'package:mobile/features/recurrences/data/repositories/recurrences_repository_impl.dart';
import 'package:mobile/features/recurrences/domain/repositories/recurrences_repository.dart';
import 'package:mobile/features/recurrences/domain/usecases/create_recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/delete_recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/list_recurrences.dart';
import 'package:mobile/features/recurrences/domain/usecases/provision_next_month.dart';
import 'package:mobile/features/recurrences/domain/usecases/update_recurrence.dart';
import 'package:mobile/features/recurrences/presentation/viewmodels/recurrences_view_model.dart';

/// Registers the recurrences feature.
void registerRecurrencesDependencies(GetIt container) {
  container
    ..registerLazySingleton<RecurrencesRemoteDataSource>(
      () => RecurrencesRemoteDataSource(container<Dio>()),
    )
    ..registerLazySingleton<RecurrencesRepository>(
      () => RecurrencesRepositoryImpl(container<RecurrencesRemoteDataSource>()),
    )
    ..registerLazySingleton<ListRecurrences>(
      () => ListRecurrences(container<RecurrencesRepository>()),
    )
    ..registerLazySingleton<CreateRecurrence>(
      () => CreateRecurrence(container<RecurrencesRepository>()),
    )
    ..registerLazySingleton<UpdateRecurrence>(
      () => UpdateRecurrence(container<RecurrencesRepository>()),
    )
    ..registerLazySingleton<DeleteRecurrence>(
      () => DeleteRecurrence(container<RecurrencesRepository>()),
    )
    ..registerLazySingleton<ProvisionNextMonth>(
      () => ProvisionNextMonth(container<RecurrencesRepository>()),
    )
    ..registerFactory<RecurrencesViewModel>(
      () => RecurrencesViewModel(
        listRecurrences: container<ListRecurrences>(),
        createRecurrence: container<CreateRecurrence>(),
        updateRecurrence: container<UpdateRecurrence>(),
        deleteRecurrence: container<DeleteRecurrence>(),
        provisionNextMonth: container<ProvisionNextMonth>(),
      ),
    );
}
