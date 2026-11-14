import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/entries/data/models/financial_entry_dto.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';

/// Calls the entries list endpoint.
class EntriesRemoteDataSource {
  const EntriesRemoteDataSource(this._dio);

  /// The API refuses a search text longer than this.
  static const maxSearchLength = 100;

  final Dio _dio;

  Future<Result<FinancialEntryPageDto>> search({
    required int offset,
    required int limit,
    String? userId,
    EntryStatus? status,
    DateTime? referenceMonth,
    EntryFilters filters = const EntryFilters(),
    String search = '',
    String? transactionId,
  }) => apiCall(() async {
    final text = search.trim();
    final from = filters.dueFrom;
    final to = filters.dueTo;
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.financialEntries.path,
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'user_id': ?userId,
        'status': ?status?.apiValue,
        // Any day of the month picks the month; both ends are the same month.
        'reference_month_from': ?_monthParam(referenceMonth),
        'reference_month_to': ?_monthParam(referenceMonth),
        'bank_account_id': ?filters.accountId,
        'type': ?filters.type?.apiValue,
        'payment_type': ?filters.paymentType?.apiValue,
        'due_date_from': ?(from == null ? null : DateFormatter.toApiDate(from)),
        'due_date_to': ?(to == null ? null : DateFormatter.toApiDate(to)),
        'min_amount': ?filters.minAmount?.toString(),
        'max_amount': ?filters.maxAmount?.toString(),
        'transaction_id': ?transactionId,
        if (text.isNotEmpty)
          'search': text.length > maxSearchLength
              ? text.substring(0, maxSearchLength)
              : text,
      },
    );
    return FinancialEntryPageDto.fromJson(response.data!);
  });

  static String? _monthParam(DateTime? month) => month == null
      ? null
      : DateFormatter.toApiDate(DateTime(month.year, month.month));
}
