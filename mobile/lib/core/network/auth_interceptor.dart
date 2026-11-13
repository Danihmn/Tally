import 'package:dio/dio.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/storage/session_token_store.dart';

/// Adds the Bearer token and handles an expired session.
///
/// On 401 from any endpoint except login, it clears the token and notifies
/// [SessionExpiredNotifier]. A 401 from login only means wrong credentials.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this._tokenStore, required this._notifier});

  /// Endpoints that work without a token.
  static const publicPaths = {'/auth/login'};

  final SessionTokenStore _tokenStore;
  final SessionExpiredNotifier _notifier;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!publicPaths.contains(options.path)) {
      final token = await _tokenStore.read();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    if (isUnauthorized && !publicPaths.contains(err.requestOptions.path)) {
      await _tokenStore.clear();
      _notifier.notifyExpired();
    }
    handler.next(err);
  }
}
