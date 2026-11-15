import 'package:equatable/equatable.dart';

/// What the server streams for one question.
sealed class ChatStreamEvent extends Equatable {
  const ChatStreamEvent();

  @override
  List<Object?> get props => const [];
}

/// Always first: which conversation the answer belongs to.
final class ChatMeta extends ChatStreamEvent {
  const ChatMeta({
    required this.conversationId,
    required this.title,
    required this.isNew,
  });

  final String conversationId;
  final String title;
  final bool isNew;

  @override
  List<Object?> get props => [conversationId, title, isNew];
}

/// A piece of the answer text, to append.
final class ChatToken extends ChatStreamEvent {
  const ChatToken(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// The answer is complete. Carries the new usage of the conversation.
final class ChatDone extends ChatStreamEvent {
  const ChatDone({required this.contextTokens, required this.tokenLimit});

  final int contextTokens;
  final int tokenLimit;

  @override
  List<Object?> get props => [contextTokens, tokenLimit];
}

/// The server failed while answering. [code] is a short machine code.
final class ChatStreamError extends ChatStreamEvent {
  const ChatStreamError(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}
