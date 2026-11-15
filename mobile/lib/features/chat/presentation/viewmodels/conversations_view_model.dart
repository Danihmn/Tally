import 'package:flutter/foundation.dart';
import 'package:mobile/core/pagination/paginated_view_model.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/domain/entities/conversation.dart';
import 'package:mobile/features/chat/domain/usecases/get_conversations.dart';

/// The conversation history: a paginated list, newest activity first.
class ConversationsViewModel extends ChangeNotifier
    with PaginatedViewModel<Conversation> {
  ConversationsViewModel({required this._getConversations});

  final GetConversations _getConversations;

  @override
  Future<Result<PageResult<Conversation>>> fetchPage({
    required int offset,
    required int limit,
  }) => _getConversations(offset: offset, limit: limit);
}
