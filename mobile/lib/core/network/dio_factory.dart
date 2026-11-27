import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/network/auth_interceptor.dart';
import 'package:mobile/core/network/error_interceptor.dart';
import 'package:mobile/core/network/safe_log_interceptor.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/storage/session_token_store.dart';

/// Builds the one [Dio] client used by every remote data source.
abstract final class DioFactory {
  static Dio create({
    required AppConfig config,
    required SessionTokenStore tokenStore,
    required SessionExpiredNotifier notifier,
    bool enableLogging = kDebugMode,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {Headers.acceptHeader: Headers.jsonContentType},
      ),
    );
    // Order matters: the auth interceptor reads the raw 401 first, then the
    // error interceptor converts the error into a Failure.
    dio.interceptors.addAll([
      AuthInterceptor(dio: dio, tokenStore: tokenStore, notifier: notifier),
      ErrorInterceptor(),
      if (enableLogging) SafeLogInterceptor(),
    ]);
    return dio;
  }
}
