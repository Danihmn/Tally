import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/app_config.dart';

void main() {
  group('AppConfig.parse', () {
    test('reads_url_and_environment', () {
      final config = AppConfig.parse(
        apiBaseUrl: 'http://10.0.2.2:8000',
        environment: 'dev',
      );
      expect(config.apiBaseUrl, 'http://10.0.2.2:8000');
      expect(config.environment, AppEnvironment.dev);
      expect(config.isProd, isFalse);
    });

    test('removes_the_trailing_slash_of_the_url', () {
      final config = AppConfig.parse(
        apiBaseUrl: 'https://api.example.com/',
        environment: 'prod',
      );
      expect(config.apiBaseUrl, 'https://api.example.com');
    });

    test('fails_with_a_clear_error_when_url_is_missing', () {
      expect(
        () => AppConfig.parse(apiBaseUrl: '  ', environment: 'dev'),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('API_BASE_URL is missing'),
          ),
        ),
      );
    });

    test('rejects_a_url_that_is_not_http_or_https', () {
      expect(
        () => AppConfig.parse(apiBaseUrl: 'ftp://host', environment: 'dev'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => AppConfig.parse(apiBaseUrl: 'not a url', environment: 'dev'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('rejects_cleartext_http_in_prod', () {
      expect(
        () => AppConfig.parse(
          apiBaseUrl: 'http://api.example.com',
          environment: 'prod',
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('rejects_an_unknown_environment', () {
      expect(
        () => AppConfig.parse(
          apiBaseUrl: 'https://api.example.com',
          environment: 'staging',
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
