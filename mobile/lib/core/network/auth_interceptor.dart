import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/storage/session_token_store.dart';

/// Adds the Bearer token and renews it when it expires.
///
/// On 401 from a protected endpoint, it asks `/auth/refresh` for a new pair of
/// tokens and repeats the request once. The user only goes back to the login
/// screen ([SessionExpiredNotifier]) when the API rejects the refresh token.
/// A 401 from login, refresh or logout is never retried.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._dio,
    required this._tokenStore,
    required this._notifier,
  });

  /// Endpoints that work without a token.
  static final publicPaths = {
    ApiEndpoints.login.path,
    ApiEndpoints.refresh.path,
    ApiEndpoints.logout.path,
  };

  /// Marks a request that was already repeated after a refresh.
  static const _retriedKey = 'auth_retried';

  /// The same client the interceptor belongs to: used to refresh and to repeat.
  final Dio _dio;
  final SessionTokenStore _tokenStore;
  final SessionExpiredNotifier _notifier;

  /// The refresh in progress. A refresh rotates the refresh token, so requests
  /// that fail together must share one refresh instead of each starting its own.
  Future<_RefreshResult>? _refreshing;

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
    final request = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    if (!isUnauthorized || publicPaths.contains(request.path)) {
      return handler.next(err);
    }
    if (request.extra[_retriedKey] == true) {
      // Even a fresh token was refused: the session is over.
      await _endSession();
      return handler.next(err);
    }

    switch (await _renewTokens(request)) {
      case _RefreshResult.renewed:
        return _repeat(request, handler);
      case _RefreshResult.rejected:
        await _endSession();
        return handler.next(err);
      case _RefreshResult.unavailable:
        // The API could not be reached: keep the tokens and try again later.
        return handler.next(err);
    }
  }

  /// Makes sure the stored access token is newer than the one that failed.
  Future<_RefreshResult> _renewTokens(RequestOptions failed) async {
    final current = await _tokenStore.read();
    final sent = failed.headers['Authorization'];
    if (current != null && current.isNotEmpty && sent != 'Bearer $current') {
      // Another request already refreshed while this one was in the air.
      return _RefreshResult.renewed;
    }
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<_RefreshResult> _refresh() async {
    final refreshToken = await _tokenStore.readRefresh();
    if (refreshToken == null || refreshToken.isEmpty) {
      return _RefreshResult.rejected;
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh.path,
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      final accessToken = data?['access_token'];
      final newRefreshToken = data?['refresh_token'];
      if (accessToken is! String ||
          accessToken.isEmpty ||
          newRefreshToken is! String ||
          newRefreshToken.isEmpty) {
        return _RefreshResult.unavailable;
      }
      await _tokenStore.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );
      return _RefreshResult.renewed;
    } on DioException catch (e) {
      return e.response?.statusCode == 401
          ? _RefreshResult.rejected
          : _RefreshResult.unavailable;
    }
  }

  Future<void> _repeat(
    RequestOptions request,
    ErrorInterceptorHandler handler,
  ) async {
    request.extra[_retriedKey] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<void> _endSession() async {
    await _tokenStore.clear();
    _notifier.notifyExpired();
  }
}

enum _RefreshResult { renewed, rejected, unavailable }
