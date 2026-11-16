import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/widgets/confirm_dialog.dart';
import 'package:mobile/core/widgets/failure_message.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_args.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_row.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_status.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/linked_entries_view_model.dart';
import 'package:mobile/features/transactions/presentation/widgets/link_entry_sheet.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "Lançamento vinculado": the entries matched with a transaction, with a
/// button to link one by hand and one to unlink each. It loads by itself:
/// while it loads, or if it fails, the rest of the detail screen stays as it
/// is.
class LinkedEntrySection extends StatefulWidget {
  const LinkedEntrySection({
    super.key,
    required this.transactionId,
    required this.isIncome,
    required this.createViewModel,
    this.onOpenEntry,
  });

  final String transactionId;

  /// A credit is linked with revenues, a debit with expenses.
  final bool isIncome;
  final LinkedEntriesViewModel Function(String transactionId) createViewModel;

  /// Defaults to opening the entry detail with the router.
  final ValueChanged<EntryDetailArgs>? onOpenEntry;

  @override
  State<LinkedEntrySection> createState() => _LinkedEntrySectionState();
}

class _LinkedEntrySectionState extends State<LinkedEntrySection> {
  late final LinkedEntriesViewModel _viewModel = widget.createViewModel(
    widget.transactionId,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_viewModel.load());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _open(FinancialEntry entry) {
    final vm = _viewModel;
    final args = EntryDetailArgs(
      entry: entry,
      account: vm.accountOf(entry.accountId),
      owner: vm.memberOf(entry.ownerId),
      ownerColorIndex: vm.memberIndexOf(entry.ownerId),
    );
    final open = widget.onOpenEntry;
    if (open != null) {
      open(args);
    } else {
      unawaited(context.push(AppRoutes.entryDetail, extra: args));
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _link() async {
    final type = widget.isIncome ? EntryType.revenues : EntryType.expenses;
    final linked = await LinkEntrySheet.show(
      context,
      candidates: (search) =>
          _viewModel.candidates(type: type, search: search),
      onLink: (entry) => _viewModel.link(entry.id),
    );
    if (linked != true || !mounted) return;
    _notice(AppLocalizations.of(context).linkEntryDone);
  }

  Future<void> _unlink(FinancialEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.unlinkEntryTitle,
      message: l10n.unlinkEntryText,
      confirmLabel: l10n.unlinkEntryAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final failure = await _viewModel.unlink(entry.id);
    if (!mounted) return;
    if (failure != null) {
      showFailureSnackBar(context, failure);
      return;
    }
    _notice(l10n.unlinkEntryDone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = TallyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_rounded, size: 18, color: colors.income),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                l10n.linkedEntryTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => unawaited(_link()),
              icon: const Icon(Icons.add_link_rounded, size: 18),
              label: Text(l10n.linkEntryShort),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => _body(context, l10n, theme),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    switch (_viewModel.state) {
      case UiInitial<List<FinancialEntry>>() ||
          UiLoading<List<FinancialEntry>>():
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Skeleton(height: 40),
          ),
        );
      case UiError<List<FinancialEntry>>():
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Text(l10n.linkedLoadError, style: muted),
                TextButton(
                  onPressed: () => unawaited(_viewModel.load()),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        );
      case UiEmpty<List<FinancialEntry>>():
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.linkedEntryNone, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(l10n.linkedEntryNoneText, style: muted),
              ],
            ),
          ),
        );
      case UiSuccess<List<FinancialEntry>>(:final data):
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < data.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _LinkedEntryTile(
                  entry: data[i],
                  onTap: () => _open(data[i]),
                  onUnlink: () => unawaited(_unlink(data[i])),
                ),
              ],
            ],
          ),
        );
    }
  }
}

class _LinkedEntryTile extends StatelessWidget {
  const _LinkedEntryTile({
    required this.entry,
    required this.onTap,
    required this.onUnlink,
  });

  final FinancialEntry entry;
  final VoidCallback onTap;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = TallyColors.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EllipsisText(
                    entry.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  EllipsisText(entryDatesLine(l10n, entry), style: muted),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                EllipsisText(
                  MoneyFormatter.signed(
                    entry.amount,
                    isIncome: entry.isRevenue,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: entry.isRevenue ? colors.income : null,
                  ),
                ),
                const SizedBox(height: 4),
                const EntryStatusBadge(badge: EntryBadge.reconciled),
              ],
            ),
            IconButton(
              onPressed: onUnlink,
              tooltip: l10n.unlinkEntryAction,
              icon: const Icon(Icons.link_off_rounded),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
