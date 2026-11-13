import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/auth/data/models/token_dto.dart';

/// Calls the login endpoint.
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
}
