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
}
