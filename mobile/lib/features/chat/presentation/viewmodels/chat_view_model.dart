import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/chat_stream_event.dart';
import 'package:mobile/features/chat/domain/entities/conversation.dart';
import 'package:mobile/features/chat/domain/usecases/get_conversation.dart';
import 'package:mobile/features/chat/domain/usecases/send_chat_message.dart';

/// State of the Tally IA chat: the messages of one conversation, the answer
/// that is streaming, and how full the conversation is.
class ChatViewModel extends ChangeNotifier {
  ChatViewModel({required this._sendMessage, required this._getConversation});

  /// The API refuses a longer message.
  static const maxMessageLength = 2000;

  final SendChatMessage _sendMessage;
  final GetConversation _getConversation;

  final List<ChatMessage> _messages = [];
  String? _conversationId;
  String _title = '';
  TokenUsage _usage = TokenUsage.empty;
  bool _serverSaidFull = false;
  bool _streaming = false;
  bool _loadingHistory = false;
  Failure? _failure;
  Failure? _historyFailure;
  String? _openedId;
  String? _lastQuestion;
  int _generation = 0;
  int _localIds = 0;
  bool _disposed = false;

  /// The messages in order, oldest first.
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String? get conversationId => _conversationId;
  String get title => _title;
  TokenUsage get usage => _usage;

  /// An answer is on its way (typing indicator, composer off).
  bool get isStreaming => _streaming;

  /// Streaming, and not a single character of the answer arrived yet.
  bool get isTyping =>
      _streaming &&
      _messages.isNotEmpty &&
      _messages.last.role == ChatRole.assistant &&
      _messages.last.content.isEmpty;

  /// Loading the history of a conversation opened from the list.
  bool get isLoadingHistory => _loadingHistory;

  /// The last question failed. The view shows an error bubble with retry.
  Failure? get failure => _failure;

  /// Opening a stored conversation failed.
  Failure? get historyFailure => _historyFailure;

  bool get isEmpty => _messages.isEmpty && !_loadingHistory;

  /// Near the limit: the view shows a warning.
  bool get isWarning => !isBlocked && _usage.isWarning;

  /// Full: read-only, the user starts a new conversation.
  bool get isBlocked => _serverSaidFull || _usage.isFull;

  /// Sends [text]. Ignored when empty, too long, already streaming or full.
  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty ||
        message.length > maxMessageLength ||
        _streaming ||
        isBlocked) {
      return;
    }
    _failure = null;
    _messages.add(
      ChatMessage(id: _localId(), role: ChatRole.user, content: message),
    );
    await _run(message);
  }

  /// Sends the last question again after a failure.
  Future<void> retry() async {
    final question = _lastQuestion;
    if (question == null || _failure == null || _streaming) return;
    _failure = null;
    await _run(question);
  }

  /// Forgets the current conversation: the next message starts a new one.
  void startNew() {
    _reset();
    _notify();
  }

  /// Opens a stored conversation to read it and go on.
  Future<void> open(String id) async {
    _reset();
    final generation = _generation;
    _openedId = id;
    _loadingHistory = true;
    _notify();
    final result = await _getConversation(id);
    if (generation != _generation || _disposed) return;
    _loadingHistory = false;
    switch (result) {
      case Success<ConversationDetail>(:final value):
        _conversationId = value.conversation.id;
        _title = value.conversation.title;
        _usage = value.conversation.usage;
        _messages.addAll(value.messages);
      case Err<ConversationDetail>(:final failure):
        _historyFailure = failure;
    }
    _notify();
  }

  /// Tries the history of the conversation that failed to open again.
  Future<void> reopen() async {
    final id = _openedId;
    if (id != null) await open(id);
  }

  Future<void> _run(String question) async {
    _lastQuestion = question;
    final generation = ++_generation;
    _streaming = true;
    final answer = ChatMessage(
      id: _localId(),
      role: ChatRole.assistant,
      content: '',
    );
    _messages.add(answer);
    _notify();

    Failure? failed;
    var finished = false;
    await for (final result in _sendMessage(
      message: question,
      conversationId: _conversationId,
    )) {
      if (generation != _generation || _disposed) return;
      switch (result) {
        case Err<ChatStreamEvent>(:final failure):
          failed = failure;
        case Success<ChatStreamEvent>(:final value):
          switch (value) {
            case ChatMeta():
              _conversationId = value.conversationId;
              _title = value.title;
            case ChatToken():
              final last = _messages.length - 1;
              _messages[last] = _messages[last].withContent(
                _messages[last].content + value.text,
              );
            case ChatDone():
              _usage = TokenUsage(
                contextTokens: value.contextTokens,
                tokenLimit: value.tokenLimit,
              );
              finished = true;
            case ChatStreamError():
              failed = const ServerUnavailableFailure();
          }
      }
      if (failed != null) break;
      _notify();
    }
    if (generation != _generation || _disposed) return;
    _streaming = false;
    // A stream that ends without `done` was cut.
    failed ??= finished ? null : const NetworkFailure();
    if (failed != null) _onFailed(failed);
    _notify();
  }

  void _onFailed(Failure failure) {
    // Drop the half answer (a retry asks again).
    _messages.removeLast();
    if (failure is ConversationFullFailure) {
      // Nothing was answered: take the question out too.
      _messages.removeLast();
      _serverSaidFull = true;
      _failure = null;
      return;
    }
    _failure = failure;
  }

  void _reset() {
    _generation++;
    _messages.clear();
    _conversationId = null;
    _title = '';
    _usage = TokenUsage.empty;
    _serverSaidFull = false;
    _streaming = false;
    _loadingHistory = false;
    _failure = null;
    _historyFailure = null;
    _openedId = null;
    _lastQuestion = null;
  }

  String _localId() => 'local-${_localIds++}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
