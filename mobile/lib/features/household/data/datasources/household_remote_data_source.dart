import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/data/models/member_dto.dart';

/// Calls the user endpoints.
class HouseholdRemoteDataSource {
  const HouseholdRemoteDataSource(this._dio);

  /// The largest page the API accepts.
  static const _pageSize = 100;

  final Dio _dio;

  Future<Result<MemberDto>> getMe() => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.me.path);
    return MemberDto.fromJson(response.data!);
  });

  Future<Result<List<MemberDto>>> getUsers() => apiCall(() async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.users.path,
      queryParameters: {'limit': _pageSize},
    );
    return [
      for (final item in response.data!)
        MemberDto.fromJson(item as Map<String, dynamic>),
    ];
  });
}
