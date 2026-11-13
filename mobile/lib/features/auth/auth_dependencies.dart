import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/login.dart';
import 'package:mobile/features/auth/domain/usecases/logout.dart';
import 'package:mobile/features/auth/presentation/viewmodels/login_view_model.dart';

/// Registers the auth feature. The ViewModel is a factory: one per screen.
void registerAuthDependencies(GetIt container) {
  container
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(container<Dio>()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remote: container<AuthRemoteDataSource>(),
        tokenStore: container<SessionTokenStore>(),
      ),
    )
    ..registerLazySingleton<Login>(() => Login(container<AuthRepository>()))
    ..registerLazySingleton<Logout>(() => Logout(container<AuthRepository>()))
    ..registerFactory<LoginViewModel>(
      () => LoginViewModel(
        login: container<Login>(),
        session: container<SessionController>(),
      ),
    );
}
