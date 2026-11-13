/// Thrown when the app is started with a missing or unsafe configuration.
class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}

/// Where the app is running.
enum AppEnvironment {
  dev,
  prod;

  static AppEnvironment parse(String value) => switch (value.toLowerCase()) {
    'prod' || 'production' => AppEnvironment.prod,
    'dev' || 'development' || '' => AppEnvironment.dev,
    _ => throw ConfigException(
      'ENVIRONMENT must be "dev" or "prod", got "$value".',
    ),
  };
}

/// App settings read from `--dart-define`, never hardcoded.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.environment});

  /// Reads `API_BASE_URL` and `ENVIRONMENT` given at build time.
  factory AppConfig.fromEnvironment() => AppConfig.parse(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    environment: const String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'dev',
    ),
  );

  /// Validates raw values. Kept separate from [fromEnvironment] so tests can
  /// call it (`String.fromEnvironment` only works with compile-time values).
  factory AppConfig.parse({
    required String apiBaseUrl,
    required String environment,
  }) {
    final env = AppEnvironment.parse(environment.trim());
    final url = apiBaseUrl.trim();
    if (url.isEmpty) {
      throw const ConfigException(
        'API_BASE_URL is missing. Run with --dart-define=API_BASE_URL=<url>.',
      );
    }
    final uri = Uri.tryParse(url);
    final validScheme =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (!validScheme || uri.host.isEmpty) {
      throw ConfigException('API_BASE_URL is not a valid http(s) URL: "$url".');
    }
    // Release builds talk HTTPS only, so a cleartext URL is a config mistake.
    if (env == AppEnvironment.prod && uri.scheme != 'https') {
      throw const ConfigException('API_BASE_URL must use https in prod.');
    }
    return AppConfig(
      apiBaseUrl: url.endsWith('/') ? url.substring(0, url.length - 1) : url,
      environment: env,
    );
  }

  final String apiBaseUrl;
  final AppEnvironment environment;

  bool get isProd => environment == AppEnvironment.prod;
}
