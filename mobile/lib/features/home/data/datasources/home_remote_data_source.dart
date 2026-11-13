import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/home/data/models/home_dtos.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/entry_type.dart';

/// Calls the analysis and planning endpoints of the home.
///
/// The paths come from `ApiEndpoints`. Every period is sent with both
/// `date_from` and `date_to` (the API wants both or none).
class HomeRemoteDataSource {
  const HomeRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Result<AmountDto>> totalExpenses(DateRange range, {String? userId}) =>
      _amount(ApiEndpoints.totalExpenses, 'total', _period(range, userId));

  Future<Result<AmountDto>> totalRevenues(DateRange range, {String? userId}) =>
      _amount(ApiEndpoints.totalRevenues, 'total', _period(range, userId));

  Future<Result<AmountDto>> balance(DateRange range, {String? userId}) =>
      _amount(ApiEndpoints.balance, 'balance', _period(range, userId));

  Future<Result<AmountDto>> averageDailyExpenses(
    DateRange range, {
    String? userId,
  }) => _amount(
    ApiEndpoints.averageDailyExpenses,
    'average',
    _period(range, userId),
  );

  Future<Result<List<DailyAmountDto>>> dailyExpenses(
    DateRange range, {
    String? userId,
  }) => apiCall(() async {
    final json = await _get(ApiEndpoints.dailyExpenses, _period(range, userId));
    return [
      for (final item in json['items'] as List<dynamic>)
        DailyAmountDto.fromJson(item as Map<String, dynamic>),
    ];
  });

  Future<Result<List<TopExpenseDto>>> topExpenses(
    DateRange range, {
    required int limit,
    String? userId,
  }) => apiCall(() async {
    final json = await _get(ApiEndpoints.topExpenses, {
      ..._period(range, userId),
      'limit': limit,
    });
    return [
      for (final item in json['items'] as List<dynamic>)
        TopExpenseDto.fromJson(item as Map<String, dynamic>),
    ];
  });

  Future<Result<AmountDto>> totalPlanned(
    DateRange months,
    EntryType type, {
    String? userId,
  }) => _amount(
    ApiEndpoints.totalPlanned,
    'total',
    _planning(months, type, userId),
  );

  Future<Result<AmountDto>> totalReconciled(
    DateRange months,
    EntryType type, {
    String? userId,
  }) => _amount(
    ApiEndpoints.totalReconciled,
    'total',
    _planning(months, type, userId),
  );

  Future<Result<ReconciliationCountsDto>> reconciliationCounts(
    DateRange months,
    EntryType type, {
    String? userId,
  }) => apiCall(() async {
    final json = await _get(
      ApiEndpoints.reconciliationCounts,
      _planning(months, type, userId),
    );
    return ReconciliationCountsDto.fromJson(json);
  });

  Future<Result<List<UpcomingEntryDto>>> upcomingEntries({
    required int days,
    String? userId,
  }) => apiCall(() async {
    final json = await _get(ApiEndpoints.upcomingEntries, {
      'days': days,
      'user_id': ?userId,
    });
    return [
      for (final item in json['items'] as List<dynamic>)
        UpcomingEntryDto.fromJson(item as Map<String, dynamic>),
    ];
  });

  Future<Result<AmountDto>> _amount(
    ApiEndpoint endpoint,
    String key,
    Map<String, dynamic> query,
  ) => apiCall(() async {
    final json = await _get(endpoint, query);
    return AmountDto.fromJson(json, key: key);
  });

  Future<Map<String, dynamic>> _get(
    ApiEndpoint endpoint,
    Map<String, dynamic> query,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      endpoint.path,
      queryParameters: query,
    );
    return response.data!;
  }

  Map<String, dynamic> _period(DateRange range, String? userId) => {
    'date_from': DateFormatter.toApiDate(range.from),
    'date_to': DateFormatter.toApiDate(range.to),
    'user_id': ?userId,
  };

  Map<String, dynamic> _planning(
    DateRange months,
    EntryType type,
    String? userId,
  ) => {..._period(months, userId), 'type': type.apiValue};
}
