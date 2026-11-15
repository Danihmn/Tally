import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/domain/entities/conversation.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

/// Loads one page of the conversation history.
class GetConversations {
  const GetConversations(this._repository);

  final ChatRepository _repository;

  Future<Result<PageResult<Conversation>>> call({
    required int offset,
    required int limit,
  }) => _repository.list(offset: offset, limit: limit);
}
