import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/widgets/error_state.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:mobile/features/chat/presentation/widgets/chat_banners.dart';
import 'package:mobile/features/chat/presentation/widgets/chat_bubbles.dart';
import 'package:mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:mobile/features/chat/presentation/widgets/chat_empty_state.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The Tally IA tab: a chat with the assistant, with markdown answers that
/// stream in, a history list and a token limit per conversation.
///
/// [onOpenHistory] defaults to the router: it opens the history and gives
/// back the id of the conversation the user picked (or `null`).
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.createViewModel,
    this.onOpenHistory,
  });

  final ChatViewModel Function() createViewModel;
  final Future<String?> Function()? onOpenHistory;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final ChatViewModel _viewModel = widget.createViewModel();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openHistory() async {
    final open = widget.onOpenHistory;
    final id = await (open != null
        ? open()
        : context.push<String>(AppRoutes.chatConversations));
    if (id == null || !mounted) return;
    await _viewModel.open(id);
  }

  void _send(String text) {
    unawaited(_viewModel.send(text));
    // The list is reversed: 0 is the newest message.
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navChat),
        actions: [
          IconButton(
            tooltip: l10n.chatHistory,
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: l10n.chatNewConversation,
            onPressed: _viewModel.startNew,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => Column(
            children: [
              Expanded(child: _body(context)),
              if (_viewModel.isWarning) const TokenWarningBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.xs,
                  AppSpacing.screenGutter,
                  AppSpacing.sm,
                ),
                child: _viewModel.isBlocked
                    ? ConversationFullBar(onStartNew: _viewModel.startNew)
                    : ChatComposer(
                        onSend: _send,
                        enabled: !_viewModel.isStreaming,
                        maxLength: ChatViewModel.maxMessageLength,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final vm = _viewModel;
    if (vm.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    final historyFailure = vm.historyFailure;
    if (historyFailure != null) {
      return ErrorState(
        failure: historyFailure,
        onRetry: () => unawaited(vm.reopen()),
      );
    }
    if (vm.isEmpty) return ChatEmptyState(onSuggestion: _send);

    final messages = vm.messages;
    final hasError = vm.failure != null;
    // Reversed list: index 0 is the bottom (error bubble, then newest).
    final extra = hasError ? 1 : 0;
    return ListView.separated(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      itemCount: messages.length + extra,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (hasError && index == 0) {
          return ErrorBubble(onRetry: () => unawaited(vm.retry()));
        }
        final message = messages[messages.length - 1 - (index - extra)];
        return switch (message.role) {
          ChatRole.user => UserBubble(text: message.content),
          ChatRole.assistant when message.content.isEmpty && vm.isTyping =>
            const TypingBubble(),
          ChatRole.assistant => AssistantBubble(markdown: message.content),
        };
      },
    );
  }
}
