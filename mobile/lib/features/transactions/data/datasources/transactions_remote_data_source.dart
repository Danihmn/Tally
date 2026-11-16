import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/transactions/data/models/transaction_dto.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';

/// Calls the transactions list endpoint and the manual link with entries.
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
    String? financialEntryId,
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
        'financial_entry_id': ?financialEntryId,
        if (text.isNotEmpty)
          'search': text.length > maxSearchLength
              ? text.substring(0, maxSearchLength)
              : text,
      },
    );
    return TransactionPageDto.fromJson(response.data!);
  });

  /// Links the transaction with the entry (the entry becomes reconciled).
  Future<Result<void>> linkEntry(String transactionId, String entryId) =>
      apiCall(() async {
        await _dio.post<void>(
          _linkPath(ApiEndpoints.linkTransactionEntry, transactionId, entryId),
        );
      });

  /// Undoes the link of the transaction with the entry.
  Future<Result<void>> unlinkEntry(String transactionId, String entryId) =>
      apiCall(() async {
        await _dio.delete<void>(
          _linkPath(
            ApiEndpoints.unlinkTransactionEntry,
            transactionId,
            entryId,
          ),
        );
      });

  static String _linkPath(
    ApiEndpoint endpoint,
    String transactionId,
    String entryId,
  ) => endpoint.path
      .replaceFirst('{transactionId}', transactionId)
      .replaceFirst('{entryId}', entryId);
}
