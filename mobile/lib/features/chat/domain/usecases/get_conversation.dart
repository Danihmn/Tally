import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

/// Loads a stored conversation with its messages.
class GetConversation {
  const GetConversation(this._repository);

  final ChatRepository _repository;

  Future<Result<ConversationDetail>> call(String id) => _repository.get(id);
}
