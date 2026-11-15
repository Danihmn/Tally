import 'dart:async';

import 'package:dio/dio.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/network/sse_parser.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/data/models/chat_event_dto.dart';
import 'package:mobile/features/chat/data/models/conversation_dto.dart';

/// Calls the Tally IA endpoints.
class ChatRemoteDataSource {
  const ChatRemoteDataSource(this._dio);

  /// The answer streams for a long time: this call waits longer than the
  /// default 20 s of the shared client.
  static const streamReceiveTimeout = Duration(minutes: 3);

  final Dio _dio;

  /// Posts the question and streams the events. A failure before or during
  /// the stream comes as an [Err] element and ends the stream.
  Stream<Result<ChatEventDto>> send({
    required String message,
    String? conversationId,
  }) async* {
    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        ApiEndpoints.chat.path,
        data: {'message': message, 'conversation_id': conversationId},
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: streamReceiveTimeout,
          headers: {Headers.acceptHeader: 'text/event-stream'},
        ),
      );
    } on DioException catch (e) {
      final error = e.error;
      yield Result.failure(switch (error) {
        // The only 409 of this endpoint is "conversation_limit_reached".
        ConflictFailure() => const ConversationFullFailure(),
        final Failure failure => failure,
        _ => const UnknownFailure(),
      });
      return;
    }
    try {
      await for (final sse in parseSse(response.data!.stream)) {
        yield Result.success(ChatEventDto.fromSse(sse));
      }
    } on DioException catch (e) {
      final error = e.error;
      yield Result.failure(
        error is Failure
            ? error
            : e.type == DioExceptionType.receiveTimeout
            ? const TimeoutFailure()
            : const NetworkFailure(),
      );
    } on FormatException {
      yield const Result.failure(UnknownFailure());
    } on Exception {
      // The connection dropped in the middle of the answer.
      yield const Result.failure(NetworkFailure());
    }
  }

  Future<Result<ConversationPageDto>> list({
    required int offset,
    required int limit,
  }) => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.conversations.path,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return ConversationPageDto.fromJson(response.data!);
  });

  Future<Result<ConversationDetailDto>> get(String id) => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.conversation.path.replaceFirst('{id}', id),
    );
    return ConversationDetailDto.fromJson(response.data!);
  });
}
