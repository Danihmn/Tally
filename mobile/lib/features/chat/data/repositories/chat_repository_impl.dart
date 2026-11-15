import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:mobile/features/chat/data/mappers/chat_mappers.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/chat_stream_event.dart';
import 'package:mobile/features/chat/domain/entities/conversation.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._remote);

  final ChatRemoteDataSource _remote;

  @override
  Stream<Result<ChatStreamEvent>> send({
    required String message,
    String? conversationId,
  }) async* {
    await for (final result in _remote.send(
      message: message,
      conversationId: conversationId,
    )) {
      switch (result) {
        case Success(:final value):
          final ChatStreamEvent? event;
          try {
            event = value.toEntity();
          } on FormatException {
            yield const Result.failure(UnknownFailure());
            return;
          }
          if (event != null) yield Result.success(event);
        case Err(:final failure):
          yield Result.failure(failure);
      }
    }
  }

  @override
  Future<Result<PageResult<Conversation>>> list({
    required int offset,
    required int limit,
  }) async => (await _remote.list(
    offset: offset,
    limit: limit,
  )).map((page) => page.toEntity());

  @override
  Future<Result<ConversationDetail>> get(String id) async =>
      (await _remote.get(id)).map((dto) => dto.toEntity());
}
