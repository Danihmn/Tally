import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/features/household/data/datasources/household_remote_data_source.dart';
import 'package:mobile/features/household/data/repositories/household_repository_impl.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

/// Registers the household feature (the logged user and the people of the house).
void registerHouseholdDependencies(GetIt container) {
  container
    ..registerLazySingleton<HouseholdRemoteDataSource>(
      () => HouseholdRemoteDataSource(container<Dio>()),
    )
    ..registerLazySingleton<HouseholdRepository>(
      () => HouseholdRepositoryImpl(container<HouseholdRemoteDataSource>()),
    )
    ..registerLazySingleton<GetMe>(
      () => GetMe(container<HouseholdRepository>()),
    )
    ..registerLazySingleton<GetHouseholdMembers>(
      () => GetHouseholdMembers(container<HouseholdRepository>()),
    )
    // One for the whole app: every screen shares "who appears".
    ..registerLazySingleton<HouseholdScopeController>(
      () => HouseholdScopeController(
        getMe: container<GetMe>(),
        getMembers: container<GetHouseholdMembers>(),
        session: container<SessionController>(),
      ),
      dispose: (controller) => controller.dispose(),
    );
}
