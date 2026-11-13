import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/data/models/bank_account_dto.dart';

/// Calls the bank accounts endpoint.
class AccountsRemoteDataSource {
  const AccountsRemoteDataSource(this._dio);

  /// The largest page the API accepts. A house has a handful of accounts.
  static const _pageSize = 100;

  final Dio _dio;

  Future<Result<List<BankAccountDto>>> getAccounts() => apiCall(() async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.bankAccounts.path,
      queryParameters: {'limit': _pageSize},
    );
    return [
      for (final item in response.data!)
        BankAccountDto.fromJson(item as Map<String, dynamic>),
    ];
  });
}
