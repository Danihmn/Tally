import 'package:mobile/core/utils/json_parsing.dart';

/// A conversation as the API sends it.
class ConversationDto {
  const ConversationDto({
    required this.id,
    required this.title,
    required this.contextTokens,
    required this.tokenLimit,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.createdAt,
    this.lastMessageAt,
  });

  factory ConversationDto.fromJson(Map<String, dynamic> json) =>
      ConversationDto(
        id: requireString(json['id'], 'id'),
        title: json['title'] as String? ?? '',
        contextTokens: requireInt(json['context_tokens'], 'context_tokens'),
        tokenLimit: requireInt(json['token_limit'], 'token_limit'),
        totalInputTokens: requireInt(
          json['total_input_tokens'],
          'total_input_tokens',
        ),
        totalOutputTokens: requireInt(
          json['total_output_tokens'],
          'total_output_tokens',
        ),
        lastMessageAt: parseDateTimeOrNull(json['last_message_at']),
        createdAt: parseDateTime(json['created_at']),
      );

  final String id;
  final String title;
  final int contextTokens;
  final int tokenLimit;
  final int totalInputTokens;
  final int totalOutputTokens;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
}

class ConversationPageDto {
  const ConversationPageDto({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory ConversationPageDto.fromJson(Map<String, dynamic> json) =>
      ConversationPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            ConversationDto.fromJson(item as Map<String, dynamic>),
        ],
        total: requireInt(json['total'], 'total'),
        limit: requireInt(json['limit'], 'limit'),
        offset: requireInt(json['offset'], 'offset'),
      );

  final List<ConversationDto> items;
  final int total;
  final int limit;
  final int offset;
}

class ChatMessageDto {
  const ChatMessageDto({
    required this.id,
    required this.role,
    required this.content,
  });

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) => ChatMessageDto(
    id: requireString(json['id'], 'id'),
    role: requireString(json['role'], 'role'),
    content: json['content'] as String? ?? '',
  );

  final String id;
  final String role;
  final String content;
}

class ConversationDetailDto {
  const ConversationDetailDto({
    required this.conversation,
    required this.messages,
  });

  factory ConversationDetailDto.fromJson(Map<String, dynamic> json) =>
      ConversationDetailDto(
        conversation: ConversationDto.fromJson(
          json['conversation'] as Map<String, dynamic>,
        ),
        messages: [
          for (final item in json['messages'] as List<dynamic>)
            ChatMessageDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final ConversationDto conversation;
  final List<ChatMessageDto> messages;
}
