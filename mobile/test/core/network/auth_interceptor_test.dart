import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/network/dio_factory.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/storage/session_token_store.dart';

import '../../support/fakes.dart';

void main() {
  late FakeSecureStorage secure;
  late SessionTokenStore tokenStore;
  late SessionExpiredNotifier notifier;
  late FakeHttpAdapter adapter;
  late Dio dio;
  late int expiredEvents;
  late StreamSubscription<void> subscription;

  setUp(() {
    secure = FakeSecureStorage();
    tokenStore = SessionTokenStore(secure);
    notifier = SessionExpiredNotifier();
    expiredEvents = 0;
    subscription = notifier.stream.listen((_) => expiredEvents++);
    adapter = FakeHttpAdapter((_) => const FakeReply(200, {'ok': true}));
    dio = DioFactory.create(
      config: const AppConfig(
        apiBaseUrl: 'http://localhost:8000',
        environment: AppEnvironment.dev,
      ),
      tokenStore: tokenStore,
      notifier: notifier,
      enableLogging: false,
    )..httpClientAdapter = adapter;
  });

  tearDown(() async {
    await subscription.cancel();
    await notifier.dispose();
  });

  group('AuthInterceptor', () {
    test('adds_the_bearer_token_to_protected_requests', () async {
      await tokenStore.save('jwt-123');
      await dio.get<dynamic>('/users/me');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer jwt-123',
      );
    });

    test('does_not_send_a_token_to_refresh_or_logout', () async {
      await tokenStore.save('old-token');
      await dio.post<dynamic>('/auth/refresh', data: {'refresh_token': 'r'});
      await dio.post<dynamic>('/auth/logout', data: {'refresh_token': 'r'});
      expect(
        adapter.requests.every((r) => r.headers['Authorization'] == null),
        isTrue,
      );
    });

    test('does_not_send_a_token_to_login', () async {
      await tokenStore.save('old-token');
      await dio.post<dynamic>('/auth/login', data: {'email': 'a@b.c'});
      expect(adapter.requests.single.headers['Authorization'], isNull);
    });

    test('sends_no_header_when_there_is_no_token', () async {
      await dio.get<dynamic>('/users/me');
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('logs_out_and_clears_token_when_api_returns_401', () async {
      await tokenStore.save('jwt-123');
      adapter = FakeHttpAdapter((_) => const FakeReply(401, {'detail': 'x'}));
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.get<dynamic>('/users/me'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await tokenStore.read(), isNull);
      expect(expiredEvents, 1);
    });

    test('notifies_only_once_when_several_requests_fail_with_401', () async {
      adapter = FakeHttpAdapter((_) => const FakeReply(401, {'detail': 'x'}));
      dio.httpClientAdapter = adapter;

      await Future.wait([
        dio
            .get<dynamic>('/transactions')
            .catchError(
              (_) => Response<dynamic>(requestOptions: RequestOptions()),
            ),
        dio
            .get<dynamic>('/bank-accounts')
            .catchError(
              (_) => Response<dynamic>(requestOptions: RequestOptions()),
            ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(expiredEvents, 1);
    });

    test('notifies_again_after_reset_following_a_new_login', () async {
      adapter = FakeHttpAdapter((_) => const FakeReply(401, {'detail': 'x'}));
      dio.httpClientAdapter = adapter;

      await dio
          .get<dynamic>('/a')
          .catchError(
            (_) => Response<dynamic>(requestOptions: RequestOptions()),
          );
      notifier.reset();
      await dio
          .get<dynamic>('/b')
          .catchError(
            (_) => Response<dynamic>(requestOptions: RequestOptions()),
          );
      await Future<void>.delayed(Duration.zero);

      expect(expiredEvents, 2);
    });

    test('wrong_credentials_on_login_do_not_expire_the_session', () async {
      await tokenStore.save('jwt-123');
      adapter = FakeHttpAdapter((_) => const FakeReply(401, {'detail': 'x'}));
      dio.httpClientAdapter = adapter;

      await dio
          .post<dynamic>('/auth/login')
          .catchError(
            (_) => Response<dynamic>(requestOptions: RequestOptions()),
          );
      await Future<void>.delayed(Duration.zero);

      expect(await tokenStore.read(), 'jwt-123');
      expect(expiredEvents, 0);
    });
  });

  group('AuthInterceptor refresh', () {
    /// Answers protected calls with 401 until they carry [validToken].
    FakeHttpAdapter apiThatAccepts(
      String validToken, {
      FakeReply Function()? onRefresh,
    }) {
      return FakeHttpAdapter((options) {
        if (options.path == '/auth/refresh') {
          return onRefresh?.call() ??
              const FakeReply(200, {
                'access_token': 'jwt-new',
                'token_type': 'bearer',
                'refresh_token': 'refresh-new',
              });
        }
        return options.headers['Authorization'] == 'Bearer $validToken'
            ? const FakeReply(200, {'ok': true})
            : const FakeReply(401, {'detail': 'expired'});
      });
    }

    Future<void> expired() async {
      await tokenStore.saveTokens(
        accessToken: 'jwt-old',
        refreshToken: 'refresh-old',
      );
    }

    test('a_401_gets_new_tokens_and_the_request_is_repeated', () async {
      await expired();
      adapter = apiThatAccepts('jwt-new');
      dio.httpClientAdapter = adapter;

      final response = await dio.get<dynamic>('/users/me');
      await Future<void>.delayed(Duration.zero);

      expect(response.statusCode, 200);
      expect(await tokenStore.read(), 'jwt-new');
      expect(await tokenStore.readRefresh(), 'refresh-new');
      expect(
        adapter.requests.map((r) => r.path),
        ['/users/me', '/auth/refresh', '/users/me'],
      );
      expect(adapter.requests[1].data, {'refresh_token': 'refresh-old'});
      expect(adapter.requests.last.headers['Authorization'], 'Bearer jwt-new');
      expect(expiredEvents, 0);
    });

    test('several_401s_at_once_share_one_refresh', () async {
      await expired();
      adapter = apiThatAccepts('jwt-new');
      dio.httpClientAdapter = adapter;

      await Future.wait([
        dio.get<dynamic>('/transactions'),
        dio.get<dynamic>('/bank-accounts'),
        dio.get<dynamic>('/users'),
      ]);

      final refreshes = adapter.requests.where((r) => r.path == '/auth/refresh');
      expect(refreshes.length, 1);
      expect(expiredEvents, 0);
    });

    test('a_rejected_refresh_token_ends_the_session', () async {
      await expired();
      adapter = apiThatAccepts(
        'never',
        onRefresh: () => const FakeReply(401, {'detail': 'Invalid'}),
      );
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.get<dynamic>('/users/me'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await tokenStore.read(), isNull);
      expect(await tokenStore.readRefresh(), isNull);
      expect(expiredEvents, 1);
    });

    test('an_unreachable_api_during_refresh_keeps_the_tokens', () async {
      await expired();
      adapter = apiThatAccepts(
        'never',
        onRefresh: () => const FakeReply(503, {}),
      );
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.get<dynamic>('/users/me'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await tokenStore.read(), 'jwt-old');
      expect(await tokenStore.readRefresh(), 'refresh-old');
      expect(expiredEvents, 0);
    });

    test('a_request_is_repeated_only_once', () async {
      await expired();
      // Even the new token is refused.
      adapter = apiThatAccepts('never-valid');
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.get<dynamic>('/users/me'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(adapter.requests.where((r) => r.path == '/users/me').length, 2);
      expect(adapter.requests.where((r) => r.path == '/auth/refresh').length, 1);
      expect(expiredEvents, 1);
    });

    test('without_a_refresh_token_a_401_ends_the_session', () async {
      await tokenStore.save('jwt-old');
      adapter = apiThatAccepts('jwt-new');
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.get<dynamic>('/users/me'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(adapter.requests.any((r) => r.path == '/auth/refresh'), isFalse);
      expect(expiredEvents, 1);
    });

    test('a_token_refreshed_meanwhile_is_used_without_another_refresh', () async {
      await expired();
      // The request left with 'jwt-old', but the stored token is already newer.
      adapter = FakeHttpAdapter((options) {
        if (options.headers['Authorization'] == 'Bearer jwt-old') {
          // Simulates another request that refreshed while this one was in the air.
          unawaited(
            tokenStore.saveTokens(
              accessToken: 'jwt-new',
              refreshToken: 'refresh-new',
            ),
          );
          return const FakeReply(401, {'detail': 'expired'});
        }
        return const FakeReply(200, {'ok': true});
      });
      dio.httpClientAdapter = adapter;

      final response = await dio.get<dynamic>('/users/me');

      expect(response.statusCode, 200);
      expect(adapter.requests.any((r) => r.path == '/auth/refresh'), isFalse);
      expect(expiredEvents, 0);
    });

    test('a_401_from_refresh_itself_is_not_retried', () async {
      await expired();
      adapter = FakeHttpAdapter((_) => const FakeReply(401, {}));
      dio.httpClientAdapter = adapter;

      await dio
          .post<dynamic>('/auth/refresh', data: {'refresh_token': 'x'})
          .catchError(
            (_) => Response<dynamic>(requestOptions: RequestOptions()),
          );

      expect(adapter.requests.length, 1);
      expect(await tokenStore.read(), 'jwt-old');
    });
  });
}
