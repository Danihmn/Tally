import 'package:equatable/equatable.dart';
import 'package:mobile/features/chat/domain/entities/conversation.dart';

enum ChatRole { user, assistant }

/// One bubble of the chat. The API sends no time for a message.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
  });

  final String id;
  final ChatRole role;

  /// Plain text for the user, markdown for the assistant.
  final String content;

  ChatMessage withContent(String value) =>
      ChatMessage(id: id, role: role, content: value);

  @override
  List<Object?> get props => [id, role, content];
}

/// A stored conversation with its messages.
class ConversationDetail extends Equatable {
  const ConversationDetail({
    required this.conversation,
    required this.messages,
  });

  final Conversation conversation;
  final List<ChatMessage> messages;

  @override
  List<Object?> get props => [conversation, messages];
}
