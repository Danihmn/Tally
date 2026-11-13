import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/household/data/datasources/household_remote_data_source.dart';
import 'package:mobile/features/household/data/repositories/household_repository_impl.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';

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
    );
}
