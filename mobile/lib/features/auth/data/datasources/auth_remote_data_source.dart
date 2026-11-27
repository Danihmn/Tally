import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/auth/data/models/token_dto.dart';

/// Calls the login and logout endpoints. The refresh call is made by the
/// `AuthInterceptor`, because it must happen in the middle of another request.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Result<TokenDto>> login({
    required String email,
    required String password,
  }) => apiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.login.path,
      data: {'email': email, 'password': password},
    );
    return TokenDto.fromJson(response.data!);
  });

  /// Tells the API to revoke the refresh token.
  Future<Result<void>> logout({required String refreshToken}) =>
      apiCall(() async {
        await _dio.post<void>(
          ApiEndpoints.logout.path,
          data: {'refresh_token': refreshToken},
        );
      });
}
