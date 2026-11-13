import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/safe_log_interceptor.dart';

import '../../support/fakes.dart';

void main() {
  group('SafeLogInterceptor', () {
    test('logs_only_method_path_status_and_time', () async {
      final lines = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..interceptors.add(SafeLogInterceptor(log: lines.add))
        ..httpClientAdapter = FakeHttpAdapter(
          (_) => const FakeReply(200, {'secret': 'value-9999'}),
        );

      await dio.post<dynamic>(
        '/auth/login',
        queryParameters: {'min_amount': '777'},
        data: {'password': 'hunter2'},
        options: Options(headers: {'Authorization': 'Bearer abc'}),
      );

      expect(lines, hasLength(1));
      expect(lines.single, matches(r'^POST /auth/login -> 200 \(\d+ms\)$'));
      for (final leaked in ['hunter2', 'abc', '777', 'value-9999']) {
        expect(lines.single, isNot(contains(leaked)));
      }
    });
  });
}
