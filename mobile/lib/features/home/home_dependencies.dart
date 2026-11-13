import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/features/auth/domain/usecases/logout.dart';
import 'package:mobile/features/home/data/datasources/home_remote_data_source.dart';
import 'package:mobile/features/home/data/repositories/home_repository_impl.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';
import 'package:mobile/features/home/domain/usecases/get_daily_spending.dart';
import 'package:mobile/features/home/domain/usecases/get_planning_progress.dart';
import 'package:mobile/features/home/domain/usecases/get_spending_by_member.dart';
import 'package:mobile/features/home/domain/usecases/get_spending_summary.dart';
import 'package:mobile/features/home/domain/usecases/get_top_expenses.dart';
import 'package:mobile/features/home/domain/usecases/get_upcoming_entries.dart';
import 'package:mobile/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

/// Registers the home feature. The ViewModel is a factory: one per screen.
void registerHomeDependencies(GetIt container) {
  container
    ..registerLazySingleton<HomeRemoteDataSource>(
      () => HomeRemoteDataSource(container<Dio>()),
    )
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(container<HomeRemoteDataSource>()),
    )
    ..registerLazySingleton<GetSpendingSummary>(
      () => GetSpendingSummary(container<HomeRepository>()),
    )
    ..registerLazySingleton<GetPlanningProgress>(
      () => GetPlanningProgress(container<HomeRepository>()),
    )
    ..registerLazySingleton<GetSpendingByMember>(
      () => GetSpendingByMember(container<HomeRepository>()),
    )
    ..registerLazySingleton<GetDailySpending>(
      () => GetDailySpending(container<HomeRepository>()),
    )
    ..registerLazySingleton<GetTopExpenses>(
      () => GetTopExpenses(container<HomeRepository>()),
    )
    ..registerLazySingleton<GetUpcomingEntries>(
      () => GetUpcomingEntries(container<HomeRepository>()),
    )
    ..registerFactory<HomeViewModel>(
      () => HomeViewModel(
        scopeController: container<HouseholdScopeController>(),
        getSummary: container<GetSpendingSummary>(),
        getPlanning: container<GetPlanningProgress>(),
        getByMember: container<GetSpendingByMember>(),
        getDaily: container<GetDailySpending>(),
        getTopExpenses: container<GetTopExpenses>(),
        getUpcoming: container<GetUpcomingEntries>(),
        logout: container<Logout>(),
        session: container<SessionController>(),
      ),
    );
}
