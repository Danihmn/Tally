import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/dio_factory.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/storage/session_token_store.dart';

import '../../support/fakes.dart';

void main() {
  Dio build(FakeReply Function(RequestOptions) reply) => DioFactory.create(
    config: const AppConfig(
      apiBaseUrl: 'http://localhost:8000',
      environment: AppEnvironment.dev,
    ),
    tokenStore: SessionTokenStore(FakeSecureStorage()),
    notifier: SessionExpiredNotifier(),
    enableLogging: false,
  )..httpClientAdapter = FakeHttpAdapter(reply);

  group('apiCall', () {
    test('returns_success_with_the_parsed_value', () async {
      final dio = build((_) => const FakeReply(200, {'answer': 'oi'}));
      final result = await apiCall(() async {
        final response = await dio.get<Map<String, dynamic>>('/tally/chat');
        return response.data!['answer'] as String;
      });
      expect(result.valueOrNull, 'oi');
    });

    test('turns_a_503_into_a_failure_and_never_a_dio_exception', () async {
      final dio = build(
        (_) => const FakeReply(503, {'detail': 'AI unavailable'}),
      );
      final result = await apiCall(() => dio.get<dynamic>('/tally/chat'));
      expect(result.failureOrNull, const ServerUnavailableFailure());
    });

    test('turns_a_bad_payload_into_an_unknown_failure', () async {
      final result = await apiCall<int>(
        () async => throw const FormatException('bad'),
      );
      expect(result.failureOrNull, const UnknownFailure());
    });
  });
}
