import 'package:dio/dio.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/network/dio_factory.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/storage/session_token_store.dart';

import 'fakes.dart';

/// A [Dio] with the real interceptors that never touches the network: every
/// request is answered by [adapter] and recorded there.
Dio buildFakeDio(
  FakeHttpAdapter adapter, {
  SessionTokenStore? tokenStore,
  SessionExpiredNotifier? notifier,
}) => DioFactory.create(
  config: const AppConfig(
    apiBaseUrl: 'http://localhost:8000',
    environment: AppEnvironment.dev,
  ),
  tokenStore: tokenStore ?? SessionTokenStore(FakeSecureStorage()),
  notifier: notifier ?? SessionExpiredNotifier(),
  enableLogging: false,
)..httpClientAdapter = adapter;
