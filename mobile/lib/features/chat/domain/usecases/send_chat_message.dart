import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/domain/entities/chat_stream_event.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

/// Sends a question to Tally AI and streams the answer.
class SendChatMessage {
  const SendChatMessage(this._repository);

  final ChatRepository _repository;

  Stream<Result<ChatStreamEvent>> call({
    required String message,
    String? conversationId,
  }) => _repository.send(message: message, conversationId: conversationId);
}
