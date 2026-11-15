import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/data/mappers/recurrence_mapper.dart';
import 'package:mobile/features/recurrences/data/models/recurrence_dto.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';

/// Calls the recurrences endpoints.
class RecurrencesRemoteDataSource {
  const RecurrencesRemoteDataSource(this._dio);

  /// The largest page the API accepts. A house has a handful of recurrences.
  static const _pageSize = 200;

  final Dio _dio;

  Future<Result<List<RecurrenceDto>>> list() => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.recurrences.path,
      queryParameters: {'limit': _pageSize},
    );
    return [
      for (final item in response.data!['items'] as List<dynamic>)
        RecurrenceDto.fromJson(item as Map<String, dynamic>),
    ];
  });

  Future<Result<RecurrenceDto>> create(RecurrenceDraft draft) =>
      apiCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiEndpoints.createRecurrence.path,
          data: draft.toJson(),
        );
        return RecurrenceDto.fromJson(response.data!);
      });

  /// Replaces the data of the recurrence with [draft].
  Future<Result<RecurrenceDto>> update(String id, RecurrenceDraft draft) =>
      apiCall(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiEndpoints.updateRecurrence.path.replaceFirst('{id}', id),
          data: draft.toJson(),
        );
        return RecurrenceDto.fromJson(response.data!);
      });

  Future<Result<void>> delete(String id) => apiCall(() async {
    await _dio.delete<void>(
      ApiEndpoints.deleteRecurrence.path.replaceFirst('{id}', id),
    );
  });

  /// Creates next month's entries from the recurrences.
  Future<Result<ProvisionResultDto>> provisionNextMonth() => apiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.provisionRecurrences.path,
    );
    return ProvisionResultDto.fromJson(response.data!);
  });
}
