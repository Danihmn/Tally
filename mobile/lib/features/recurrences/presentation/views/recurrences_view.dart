import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/widgets/confirm_dialog.dart';
import 'package:mobile/core/widgets/error_state.dart';
import 'package:mobile/core/widgets/failure_message.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/presentation/viewmodels/recurrences_view_model.dart';
import 'package:mobile/features/recurrences/presentation/widgets/recurrence_form_sheet.dart';
import 'package:mobile/features/recurrences/presentation/widgets/recurrence_row.dart';
import 'package:mobile/features/transactions/presentation/widgets/transactions_states.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The recurrences section of the planning screen: the tabs "Ativas" and
/// "Canceladas", the list, the form to create and edit, and the button that
/// provisions the next month from the active ones.
///
/// It creates its own ViewModel and loads it. [onProvisioned] is called when
/// the next month was provisioned, so the planning screen can show it.
class RecurrencesView extends StatefulWidget {
  const RecurrencesView({
    super.key,
    required this.createViewModel,
    this.onProvisioned,
  });

  final RecurrencesViewModel Function() createViewModel;
  final ValueChanged<ProvisionResult>? onProvisioned;

  @override
  State<RecurrencesView> createState() => _RecurrencesViewState();
}

class _RecurrencesViewState extends State<RecurrencesView> {
  late final RecurrencesViewModel _viewModel = widget.createViewModel();

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

  Future<void> _showSaved(Future<bool?> sheet, String message) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await sheet;
    if (saved != true) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _new() => _showSaved(
    RecurrenceFormSheet.show(
      context,
      members: _viewModel.members,
      defaultOwnerId: _viewModel.me?.id,
      onSubmit: _viewModel.create,
    ),
    AppLocalizations.of(context).recurrenceSaved,
  );

  Future<void> _edit(Recurrence recurrence) => _showSaved(
    RecurrenceFormSheet.show(
      context,
      members: _viewModel.members,
      defaultOwnerId: _viewModel.me?.id,
      initial: recurrence,
      onSubmit: (draft) => _viewModel.update(recurrence.id, draft),
    ),
    AppLocalizations.of(context).recurrenceSaved,
  );

  /// Cancels or reactivates. Cancelling asks first: it stops the entries.
  Future<void> _setStatus(
    Recurrence recurrence,
    RecurrenceStatus status,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cancelling = status == RecurrenceStatus.cancelled;
    if (cancelling) {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.recurrenceCancelTitle,
        message: l10n.recurrenceCancelText,
        confirmLabel: l10n.recurrenceCancelAction,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    final failure = await _viewModel.setStatus(recurrence.id, status);
    if (!mounted) return;
    if (failure != null) {
      showFailureSnackBar(context, failure);
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            cancelling
                ? l10n.recurrenceCancelledNotice
                : l10n.recurrenceReactivatedNotice,
          ),
        ),
      );
  }

  Future<void> _delete(Recurrence recurrence) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.recurrenceDeleteTitle,
      message: l10n.recurrenceDeleteText(recurrence.description),
      confirmLabel: l10n.entryDeleteConfirm,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final failure = await _viewModel.delete(recurrence.id);
    if (!mounted) return;
    if (failure != null) {
      showFailureSnackBar(context, failure);
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.recurrenceDeletedDone)));
  }

  Future<void> _provision() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final month = _monthName(_viewModel.nextMonth);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.provisionTitle,
      message: l10n.provisionText(month),
      confirmLabel: l10n.provisionConfirm,
    );
    if (!confirmed || !mounted) return;
    final result = await _viewModel.provisionNextMonth();
    if (!mounted) return;
    final failure = result.failureOrNull;
    final provisioned = result.valueOrNull;
    if (failure != null || provisioned == null) {
      showFailureSnackBar(context, failure!);
      return;
    }
    final shown = _monthName(provisioned.referenceMonth);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            provisioned.created == 0
                ? l10n.provisionNothingNew(shown)
                : l10n.provisionCreated(provisioned.created, shown),
          ),
        ),
      );
    widget.onProvisioned?.call(provisioned);
  }

  static String _monthName(DateTime month) =>
      DateFormatter.monthName(month).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.recurrenceNew),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _viewModel.reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.xs,
              AppSpacing.screenGutter,
              96,
            ),
            children: [
              Text(
                l10n.recurrencesIntro,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _tabs(l10n),
              const SizedBox(height: AppSpacing.sm),
              if (_viewModel.tab == RecurrenceStatus.active) ...[
                _provisionButton(l10n),
                const SizedBox(height: AppSpacing.sm),
              ],
              ..._list(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs(AppLocalizations l10n) => SizedBox(
    width: double.infinity,
    child: SegmentedButton<RecurrenceStatus>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: RecurrenceStatus.active,
          label: Text(l10n.recurrencesTabActive),
        ),
        ButtonSegment(
          value: RecurrenceStatus.cancelled,
          label: Text(l10n.recurrencesTabCancelled),
        ),
      ],
      selected: {_viewModel.tab},
      onSelectionChanged: (values) =>
          unawaited(_viewModel.selectTab(values.first)),
    ),
  );

  Widget _provisionButton(AppLocalizations l10n) {
    final busy = _viewModel.isProvisioning;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: busy ? null : _provision,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.event_repeat_rounded),
        label: Text(l10n.provisionButton(_monthName(_viewModel.nextMonth))),
      ),
    );
  }

  List<Widget> _list(AppLocalizations l10n) {
    switch (_viewModel.state) {
      case UiInitial<List<Recurrence>>() || UiLoading<List<Recurrence>>():
        return const [TransactionsSkeleton()];
      case UiError<List<Recurrence>>(:final failure):
        return [
          ErrorState(
            failure: failure,
            onRetry: () => unawaited(_viewModel.load()),
          ),
        ];
      case UiEmpty<List<Recurrence>>():
        return [
          _EmptyCard(
            title: _viewModel.tab == RecurrenceStatus.active
                ? l10n.recurrencesEmptyTitle
                : l10n.recurrencesEmptyCancelledTitle,
            text: _viewModel.tab == RecurrenceStatus.active
                ? l10n.recurrencesEmptyText
                : l10n.recurrencesEmptyCancelledText,
          ),
        ];
      case UiSuccess<List<Recurrence>>(:final data):
        return [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < data.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  RecurrenceRow(
                    recurrence: data[i],
                    ownerName: _viewModel
                        .memberOf(data[i].ownerId)
                        ?.displayName,
                    onAction: (action) => switch (action) {
                      RecurrenceAction.edit => unawaited(_edit(data[i])),
                      RecurrenceAction.cancel => unawaited(
                        _setStatus(data[i], RecurrenceStatus.cancelled),
                      ),
                      RecurrenceAction.reactivate => unawaited(
                        _setStatus(data[i], RecurrenceStatus.active),
                      ),
                      RecurrenceAction.delete => unawaited(_delete(data[i])),
                    },
                  ),
                ],
              ],
            ),
          ),
        ];
    }
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.event_repeat_rounded,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
