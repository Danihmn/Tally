import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/transactions/data/models/transaction_dto.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';

/// Calls the transactions list endpoint.
class TransactionsRemoteDataSource {
  const TransactionsRemoteDataSource(this._dio);

  /// The API refuses a search text longer than this.
  static const maxSearchLength = 100;

  final Dio _dio;

  Future<Result<TransactionPageDto>> search({
    required int offset,
    required int limit,
    String? userId,
    TransactionFilters filters = const TransactionFilters(),
    String search = '',
  }) => apiCall(() async {
    final text = search.trim();
    final from = filters.dateFrom;
    final to = filters.dateTo;
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.transactions.path,
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'user_id': ?userId,
        'bank_account_id': ?filters.accountId,
        'type': ?filters.direction?.apiValue,
        'status': ?filters.status?.apiValue,
        'date_from': ?(from == null ? null : DateFormatter.toApiDate(from)),
        'date_to': ?(to == null ? null : DateFormatter.toApiDate(to)),
        'min_amount': ?filters.minAmount?.toString(),
        'max_amount': ?filters.maxAmount?.toString(),
        if (text.isNotEmpty)
          'search': text.length > maxSearchLength
              ? text.substring(0, maxSearchLength)
              : text,
      },
    );
    return TransactionPageDto.fromJson(response.data!);
  });
}
