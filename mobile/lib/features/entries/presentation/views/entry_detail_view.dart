import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/core/widgets/empty_state.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/viewmodels/entry_actions_view_model.dart';
import 'package:mobile/features/entries/presentation/viewmodels/linked_transactions_view_model.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_args.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_detail_actions.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_icon.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_status.dart';
import 'package:mobile/features/entries/presentation/widgets/linked_transaction_section.dart';
import 'package:mobile/features/household/presentation/widgets/member_palette.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The data of one entry, its timeline and, when it is reconciled, the bank
/// transaction it is matched with. A planned or cancelled entry can be edited,
/// cancelled, reopened and deleted from here; when it changes, the screen
/// closes and answers `true`, so the list reads again.
class EntryDetailView extends StatelessWidget {
  const EntryDetailView({
    super.key,
    required this.args,
    required this.createLinkedViewModel,
    required this.createActionsViewModel,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// `null` when the screen was opened without the entry (for example after
  /// the app was restored). It then says so and goes back to the list.
  final EntryDetailArgs? args;

  /// Builds the ViewModel of the "Transação do banco" block.
  final LinkedTransactionsViewModel Function(String entryId)
  createLinkedViewModel;

  /// Builds the ViewModel of the edit, cancel, reopen and delete buttons.
  final EntryActionsViewModel Function() createActionsViewModel;
  final DateTime Function() _now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final args = this.args;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.entryDetailTitle)),
      body: args == null
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.entryDetailMissing,
              action: OutlinedButton(
                onPressed: () => context.go(AppRoutes.entries),
                child: Text(l10n.detailBack),
              ),
            )
          : _Content(
              args: args,
              createLinkedViewModel: createLinkedViewModel,
              createActionsViewModel: createActionsViewModel,
              today: () {
                final now = _now();
                return DateTime(now.year, now.month, now.day);
              }(),
            ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.args,
    required this.createLinkedViewModel,
    required this.createActionsViewModel,
    required this.today,
  });

  final EntryDetailArgs args;
  final LinkedTransactionsViewModel Function(String entryId)
  createLinkedViewModel;
  final EntryActionsViewModel Function() createActionsViewModel;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = TallyColors.of(context);
    final entry = args.entry;
    final account = args.account;
    final owner = args.owner;
    final category = entry.category?.trim();
    final notes = entry.notes?.trim();
    final due = entry.dueDate;

    final rows = <_DetailRow>[
      _DetailRow(
        l10n.detailDescription,
        EllipsisText(entry.description, tapToShow: true, maxLines: 2),
      ),
      _DetailRow(
        l10n.detailType,
        Text(entry.isRevenue ? l10n.entryTypeRevenue : l10n.entryTypeExpense),
      ),
      _DetailRow(
        l10n.entryDetailPayment,
        Text(switch (entry.paymentType) {
          PaymentType.debit => l10n.entryPayDebit,
          PaymentType.credit => l10n.entryPayCredit,
          null => '—',
        }),
      ),
      if (category != null && category.isNotEmpty)
        _DetailRow(
          l10n.detailCategory,
          EllipsisText(category, tapToShow: true),
        ),
      _DetailRow(
        l10n.filterAmount,
        EllipsisText(MoneyFormatter.format(entry.amount)),
      ),
      _DetailRow(
        l10n.entryDetailReference,
        Text(DateFormatter.monthYear(entry.referenceMonth)),
      ),
      _DetailRow(
        l10n.entryDetailDue,
        Text(due == null ? '—' : DateFormatter.date(due)),
      ),
      _DetailRow(
        l10n.detailAccount,
        EllipsisText(
          account == null
              ? '—'
              : '${account.displayName} ••${account.shortNumber}',
          tapToShow: true,
        ),
      ),
      _DetailRow(
        l10n.entryDetailInstallment,
        EllipsisText(
          entry.installmentNumber == null || entry.installmentTotal == null
              ? '—'
              : l10n.entryDetailInstallmentOf(
                  entry.installmentNumber!,
                  entry.installmentTotal!,
                ),
          tapToShow: true,
        ),
      ),
      if (owner != null)
        _DetailRow(
          l10n.detailHolder,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: MemberPalette.colorFor(
                  context,
                  args.ownerColorIndex,
                ).withValues(alpha: 0.18),
                child: Text(
                  owner.initial,
                  style: TextStyle(
                    fontSize: 11,
                    color: MemberPalette.colorFor(
                      context,
                      args.ownerColorIndex,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              EllipsisText(owner.displayName, tapToShow: true),
            ],
          ),
        ),
      _DetailRow(
        l10n.entryDetailNotes,
        EllipsisText(
          notes == null || notes.isEmpty ? '—' : notes,
          textAlign: TextAlign.end,
          tapToShow: true,
          maxLines: 3,
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: [
        Column(
          children: [
            EntryIcon(entry: entry, size: 56),
            const SizedBox(height: AppSpacing.sm),
            EllipsisText(
              MoneyFormatter.signed(entry.amount, isIncome: entry.isRevenue),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: entry.isRevenue ? colors.income : colors.expense,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            EllipsisText(
              entry.description,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
              tapToShow: true,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xs),
            EntryStatusBadge(badge: entryBadge(entry, today)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                rows[i],
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Timeline(entry: entry, owner: owner?.displayName),
        const SizedBox(height: AppSpacing.md),
        EntryDetailActions(
          entry: entry,
          accounts: args.accounts,
          today: today,
          createViewModel: createActionsViewModel,
        ),
        if (entry.status == EntryStatus.reconciled) ...[
          const SizedBox(height: AppSpacing.lg),
          LinkedTransactionSection(
            entryId: entry.id,
            createViewModel: createLinkedViewModel,
          ),
        ],
      ],
    );
  }
}

/// Created, planned, and how it ended (or that it still waits).
class _Timeline extends StatelessWidget {
  const _Timeline({required this.entry, required this.owner});

  final FinancialEntry entry;
  final String? owner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = TallyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final due = entry.dueDate;
    final created = DateFormatter.date(entry.createdAt.toLocal());
    final steps = <_Step>[
      _Step(
        l10n.entryTimelineCreated,
        owner == null ? created : l10n.entryTimelineCreatedBy(created, owner!),
        colors.income,
      ),
      _Step(
        l10n.entryTimelinePlanned,
        due == null
            ? l10n.entryTimelineNoDue
            : l10n.entryTimelineDueOn(DateFormatter.date(due)),
        entry.status == EntryStatus.planned ? scheme.primary : colors.income,
      ),
      switch (entry.status) {
        EntryStatus.reconciled => _Step(
          l10n.entryTimelineReconciled,
          l10n.entryTimelineReconciledText,
          colors.income,
        ),
        EntryStatus.cancelled => _Step(
          l10n.entryTimelineCancelled,
          l10n.entryTimelineCancelledText,
          scheme.error,
        ),
        EntryStatus.planned => _Step(
          l10n.entryTimelineWaiting,
          l10n.entryTimelineWaitingText,
          colors.warning,
        ),
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5, right: AppSpacing.sm),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: step.color,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        step.text,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Step {
  const _Step(this.title, this.text, this.color);

  final String title;
  final String text;
  final Color color;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: DefaultTextStyle.merge(
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                child: value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
