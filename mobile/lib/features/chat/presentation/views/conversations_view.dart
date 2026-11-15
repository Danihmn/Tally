import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/widgets/async_state_view.dart';
import 'package:mobile/core/widgets/failure_message.dart';
import 'package:mobile/features/chat/domain/entities/conversation.dart';
import 'package:mobile/features/chat/presentation/viewmodels/conversations_view_model.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The conversation history. Tapping a row pops with the conversation id, and
/// the chat opens it. [onSelected] replaces the pop (used in tests).
class ConversationsView extends StatefulWidget {
  const ConversationsView({
    super.key,
    required this.createViewModel,
    this.onSelected,
    this.now,
  });

  final ConversationsViewModel Function() createViewModel;
  final ValueChanged<String>? onSelected;

  /// "Today", for the relative dates. Tests pass a fixed one.
  final DateTime Function()? now;

  @override
  State<ConversationsView> createState() => _ConversationsViewState();
}

class _ConversationsViewState extends State<ConversationsView> {
  static const _loadMoreDistance = 300.0;

  late final ConversationsViewModel _viewModel = widget.createViewModel();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_viewModel.load());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreDistance) {
      unawaited(_viewModel.loadMore());
    }
  }

  void _select(Conversation conversation) {
    final select = widget.onSelected;
    if (select != null) {
      select(conversation.id);
    } else {
      context.pop(conversation.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.conversationsTitle),
        leading: IconButton(
          tooltip: l10n.conversationsBack,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => AsyncStateView<List<Conversation>>(
            state: _viewModel.state,
            onRetry: () => unawaited(_viewModel.load()),
            emptyTitle: l10n.conversationsEmptyTitle,
            emptyMessage: l10n.conversationsEmptyMessage,
            builder: (context, items) => RefreshIndicator(
              onRefresh: _viewModel.refresh,
              child: _list(context, items),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<Conversation> items) {
    final vm = _viewModel;
    final l10n = AppLocalizations.of(context);
    final now = (widget.now ?? DateTime.now)();
    final footer = vm.isLoadingMore || vm.inlineFailure != null;
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      itemCount: items.length + (footer ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          final failure = vm.inlineFailure;
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Center(
              child: failure == null
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: () => unawaited(vm.loadMore()),
                      child: Text(
                        '${failureMessage(l10n, failure)} ${l10n.retry}',
                      ),
                    ),
            ),
          );
        }
        final conversation = items[index];
        return ConversationRow(
          conversation: conversation,
          now: now,
          onTap: () => _select(conversation),
        );
      },
    );
  }
}

/// One conversation: title, when it was last used and a thin usage bar.
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.now,
    required this.onTap,
  });

  final Conversation conversation;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usage = conversation.usage;
    final percent = (usage.ratio * 100).round().clamp(0, 100);
    final title = conversation.title.trim().isEmpty
        ? l10n.conversationUntitled
        : conversation.title;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _when(l10n, conversation.activityAt.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: usage.ratio.clamp(0, 1).toDouble(),
                  minHeight: 4,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: usage.isFull ? scheme.error : scheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                l10n.conversationUsage(percent),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _when(AppLocalizations l10n, DateTime date) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return l10n.dayToday;
    if (diff == 1) return l10n.dayYesterday;
    return DateFormatter.dayMonth(date);
  }
}
