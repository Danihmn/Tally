import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/utils/json_parsing.dart';
import 'package:mobile/features/chat/data/models/chat_event_dto.dart';
import 'package:mobile/features/chat/data/models/conversation_dto.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/chat_stream_event.dart';
import 'package:mobile/features/chat/domain/entities/conversation.dart';

extension ConversationDtoMapper on ConversationDto {
  Conversation toEntity() => Conversation(
    id: id,
    title: title,
    contextTokens: contextTokens,
    tokenLimit: tokenLimit,
    totalInputTokens: totalInputTokens,
    totalOutputTokens: totalOutputTokens,
    lastMessageAt: lastMessageAt,
    createdAt: createdAt,
  );
}

extension ConversationPageDtoMapper on ConversationPageDto {
  PageResult<Conversation> toEntity() => PageResult<Conversation>(
    items: [for (final dto in items) dto.toEntity()],
    limit: limit,
    offset: offset,
    total: total,
  );
}

extension ChatMessageDtoMapper on ChatMessageDto {
  ChatMessage toEntity() => ChatMessage(
    id: id,
    // Any role that is not the user's is shown as the assistant.
    role: role == 'user' ? ChatRole.user : ChatRole.assistant,
    content: content,
  );
}

extension ConversationDetailDtoMapper on ConversationDetailDto {
  ConversationDetail toEntity() => ConversationDetail(
    conversation: conversation.toEntity(),
    messages: [for (final dto in messages) dto.toEntity()],
  );
}

extension ChatEventDtoMapper on ChatEventDto {
  /// `null` for an event name the app does not know (ignored).
  ChatStreamEvent? toEntity() => switch (name) {
    'meta' => ChatMeta(
      conversationId: requireString(data['conversation_id'], 'conversation_id'),
      title: data['title'] as String? ?? '',
      isNew: data['is_new'] == true,
    ),
    'token' => ChatToken(data['text'] as String? ?? ''),
    'done' => ChatDone(
      contextTokens: requireInt(data['context_tokens'], 'context_tokens'),
      tokenLimit: requireInt(data['token_limit'], 'token_limit'),
    ),
    'error' => ChatStreamError(data['code'] as String? ?? 'unknown'),
    _ => null,
  };
}
