import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/app/theme/theme_controller.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/network/dio_factory.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/preferences_storage.dart';
import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/accounts/accounts_dependencies.dart';
import 'package:mobile/features/auth/auth_dependencies.dart';
import 'package:mobile/features/chat/chat_dependencies.dart';
import 'package:mobile/features/entries/entries_dependencies.dart';
import 'package:mobile/features/home/home_dependencies.dart';
import 'package:mobile/features/household/household_dependencies.dart';
import 'package:mobile/features/transactions/transactions_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's service locator. Services are lazy singletons. ViewModels are
/// registered as factories by each feature (one new instance per screen).
final GetIt getIt = GetIt.instance;

/// Registers the core services. Call once at startup, before `runApp`.
Future<void> configureDependencies(AppConfig config) async {
  final preferences = await SharedPreferences.getInstance();
  registerCoreDependencies(
    getIt,
    config: config,
    secureStorage: PlatformSecureStorage(),
    preferences: SharedPreferencesStorage(preferences),
  );
  registerFeatureDependencies(getIt);
}

/// Registers what each feature needs. Kept apart so tests can build a fresh
/// container with the core services and then add the features.
void registerFeatureDependencies(GetIt container) {
  registerAuthDependencies(container);
  registerHouseholdDependencies(container);
  registerHomeDependencies(container);
  registerAccountsDependencies(container);
  registerTransactionsDependencies(container);
  registerEntriesDependencies(container);
  registerChatDependencies(container);
}

/// Registration kept apart from [configureDependencies] so tests can pass
/// fakes (no plugins, no network) into a fresh container.
void registerCoreDependencies(
  GetIt container, {
  required AppConfig config,
  required SecureStorage secureStorage,
  required PreferencesStorage preferences,
}) {
  container
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<SecureStorage>(secureStorage)
    ..registerSingleton<PreferencesStorage>(preferences)
    ..registerLazySingleton<SessionTokenStore>(
      () => SessionTokenStore(container<SecureStorage>()),
    )
    ..registerLazySingleton<SessionExpiredNotifier>(
      SessionExpiredNotifier.new,
      dispose: (notifier) => notifier.dispose(),
    )
    ..registerLazySingleton<SessionController>(
      () => SessionController(
        tokenStore: container<SessionTokenStore>(),
        expiredNotifier: container<SessionExpiredNotifier>(),
      ),
      dispose: (controller) => controller.dispose(),
    )
    ..registerLazySingleton<Dio>(
      () => DioFactory.create(
        config: container<AppConfig>(),
        tokenStore: container<SessionTokenStore>(),
        notifier: container<SessionExpiredNotifier>(),
      ),
    )
    ..registerLazySingleton<ThemeController>(
      () => ThemeController(container<PreferencesStorage>()),
      dispose: (controller) => controller.dispose(),
    );
}
