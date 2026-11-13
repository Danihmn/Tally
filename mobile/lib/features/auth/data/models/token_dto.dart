/// Answer of `POST /auth/login`: `{access_token, token_type}`.
class TokenDto {
  const TokenDto({required this.accessToken});

  /// Throws [FormatException] when the token is missing or empty, which
  /// `apiCall` turns into an `UnknownFailure`.
  factory TokenDto.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Expected an access_token.');
    }
    return TokenDto(accessToken: token);
  }

  final String accessToken;
}
