/// Answer of `POST /auth/login` and `POST /auth/refresh`:
/// `{access_token, token_type, refresh_token}`.
class TokenDto {
  const TokenDto({required this.accessToken, required this.refreshToken});

  /// Throws [FormatException] when a token is missing or empty, which
  /// `apiCall` turns into an `UnknownFailure`.
  factory TokenDto.fromJson(Map<String, dynamic> json) {
    return TokenDto(
      accessToken: _token(json, 'access_token'),
      refreshToken: _token(json, 'refresh_token'),
    );
  }

  static String _token(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! String || value.isEmpty) {
      throw FormatException('Expected a $field.');
    }
    return value;
  }

  final String accessToken;
  final String refreshToken;
}
