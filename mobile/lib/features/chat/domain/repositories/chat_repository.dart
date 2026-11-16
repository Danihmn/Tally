import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/chat_stream_event.dart';
import 'package:mobile/features/chat/domain/entities/conversation.dart';

/// Tally AI conversations.
abstract interface class ChatRepository {
  /// Sends a question and streams the answer. Each element is an event, or a
  /// failure (which ends the stream). [conversationId] `null` starts a new
  /// conversation.
  Stream<Result<ChatStreamEvent>> send({
    required String message,
    String? conversationId,
  });

  /// One page of the conversations of the user, newest activity first.
  Future<Result<PageResult<Conversation>>> list({
    required int offset,
    required int limit,
  });

  /// A conversation with its messages.
  Future<Result<ConversationDetail>> get(String id);
}
