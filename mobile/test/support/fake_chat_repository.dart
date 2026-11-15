import 'dart:async';

import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/chat_stream_event.dart';
import 'package:mobile/features/chat/domain/entities/conversation.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

Conversation makeConversation({
  String id = 'c1',
  String title = 'Gastos de novembro',
  int contextTokens = 1000,
  int tokenLimit = 50000,
  DateTime? lastMessageAt,
  DateTime? createdAt,
}) => Conversation(
  id: id,
  title: title,
  contextTokens: contextTokens,
  tokenLimit: tokenLimit,
  totalInputTokens: contextTokens,
  totalOutputTokens: 100,
  lastMessageAt: lastMessageAt,
  createdAt: createdAt ?? DateTime(2026, 11, 1),
);

/// One call to [FakeChatRepository.send].
class SendCall {
  const SendCall(this.message, this.conversationId);

  final String message;
  final String? conversationId;
}

/// [ChatRepository] with no network. [send] answers with the next stream that
/// the test queued (it controls when each event arrives).
class FakeChatRepository implements ChatRepository {
  final List<SendCall> sendCalls = [];
  final List<StreamController<Result<ChatStreamEvent>>> _queue = [];

  /// Conversations that [list] pages.
  List<Conversation> conversations = [];
  Result<PageResult<Conversation>>? listForced;
  Result<ConversationDetail>? detail;
  final List<String> getCalls = [];

  /// Queues a stream for the next [send] and returns its controller.
  StreamController<Result<ChatStreamEvent>> enqueue() {
    final controller = StreamController<Result<ChatStreamEvent>>();
    _queue.add(controller);
    return controller;
  }

  /// Queues a stream that emits [events] and ends.
  void answer(List<ChatStreamEvent> events) {
    final controller = enqueue();
    for (final event in events) {
      controller.add(Result.success(event));
    }
    unawaited(controller.close());
  }

  /// Queues a stream that fails.
  void fail(Failure failure) {
    final controller = enqueue()..add(Result.failure(failure));
    unawaited(controller.close());
  }

  @override
  Stream<Result<ChatStreamEvent>> send({
    required String message,
    String? conversationId,
  }) {
    sendCalls.add(SendCall(message, conversationId));
    return _queue.removeAt(0).stream;
  }

  @override
  Future<Result<PageResult<Conversation>>> list({
    required int offset,
    required int limit,
  }) async {
    final forced = listForced;
    if (forced != null) return forced;
    final end = (offset + limit).clamp(0, conversations.length);
    return Result.success(
      PageResult(
        items: conversations.sublist(offset.clamp(0, end), end),
        limit: limit,
        offset: offset,
        total: conversations.length,
      ),
    );
  }

  @override
  Future<Result<ConversationDetail>> get(String id) async {
    getCalls.add(id);
    return detail ?? const Result.failure(NotFoundFailure());
  }
}

/// The events of a normal answer.
List<ChatStreamEvent> normalAnswer(
  List<String> tokens, {
  String id = 'c1',
  bool isNew = true,
  int context = 1200,
  int limit = 50000,
}) => [
  ChatMeta(conversationId: id, title: 'Gastos', isNew: isNew),
  for (final text in tokens) ChatToken(text),
  ChatDone(contextTokens: context, tokenLimit: limit),
];

ChatMessage makeMessage(String id, ChatRole role, String content) =>
    ChatMessage(id: id, role: role, content: content);
