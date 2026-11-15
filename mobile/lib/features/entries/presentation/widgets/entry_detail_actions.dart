import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/widgets/confirm_dialog.dart';
import 'package:mobile/core/widgets/failure_message.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/viewmodels/entry_actions_view_model.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_form_sheet.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The buttons under the entry detail: edit, cancel or reopen, and delete. A
/// reconciled entry has none, only a note: its reconciliation comes first.
///
/// When one of them works, the screen closes and answers `true`.
class EntryDetailActions extends StatefulWidget {
  const EntryDetailActions({
    super.key,
    required this.entry,
    required this.accounts,
    required this.today,
    required this.createViewModel,
  });

  final FinancialEntry entry;
  final List<BankAccount> accounts;
  final DateTime today;
  final EntryActionsViewModel Function() createViewModel;

  @override
  State<EntryDetailActions> createState() => _EntryDetailActionsState();
}

class _EntryDetailActionsState extends State<EntryDetailActions> {
  late final EntryActionsViewModel _viewModel = widget.createViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// Shows [message] and closes the detail, answering `true`.
  void _done(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    unawaited(Navigator.of(context).maybePop(true));
  }

  Future<void> _run(
    Future<Failure?> Function() action,
    String successMessage,
  ) async {
    final failure = await action();
    if (!mounted) return;
    if (failure != null) {
      showFailureSnackBar(context, failure);
      return;
    }
    _done(successMessage);
  }

  Future<void> _edit() async {
    final l10n = AppLocalizations.of(context);
    final entry = widget.entry;
    final saved = await EntryFormSheet.show(
      context,
      accounts: widget.accounts,
      initial: entry,
      now: widget.today,
      onSubmit: (draft) => _viewModel.update(entry.id, draft),
    );
    if (saved == true && mounted) _done(l10n.entrySaved);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final entry = widget.entry;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.entryDeleteTitle,
      message: l10n.entryDeleteText(entry.description),
      confirmLabel: l10n.entryDeleteConfirm,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => _viewModel.delete(entry.id), l10n.entryDeletedDone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = widget.entry;
    if (entry.status == EntryStatus.reconciled) {
      return Text(
        l10n.entryReconciledLocked,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final busy = _viewModel.isBusy;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.entryActionEdit),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (entry.status == EntryStatus.cancelled)
              FilledButton.tonal(
                onPressed: busy
                    ? null
                    : () => unawaited(
                        _run(
                          () => _viewModel.reopen(entry.id),
                          l10n.entryReopenedDone,
                        ),
                      ),
                child: Text(l10n.entryActionReopen),
              )
            else
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error),
                ),
                onPressed: busy
                    ? null
                    : () => unawaited(
                        _run(
                          () => _viewModel.cancel(entry.id),
                          l10n.entryCancelledDone,
                        ),
                      ),
                child: Text(l10n.entryActionCancel),
              ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              onPressed: busy ? null : _delete,
              child: Text(l10n.entryActionDelete),
            ),
          ],
        );
      },
    );
  }
}
