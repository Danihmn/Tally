import 'dart:convert';

import 'package:mobile/core/network/sse_parser.dart';

/// One SSE event of `POST /tally/chat`: its name and the decoded JSON data.
class ChatEventDto {
  const ChatEventDto({required this.name, required this.data});

  /// Throws [FormatException] when the data is not a JSON object.
  factory ChatEventDto.fromSse(SseMessage message) {
    final decoded = jsonDecode(message.data);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object in the event.');
    }
    return ChatEventDto(name: message.event, data: decoded);
  }

  final String name;
  final Map<String, dynamic> data;
}
