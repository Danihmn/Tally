import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/empty_state.dart';
import 'package:mobile/features/household/presentation/widgets/member_palette.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/linked_entries_view_model.dart';
import 'package:mobile/features/transactions/presentation/views/transaction_detail_args.dart';
import 'package:mobile/features/transactions/presentation/widgets/linked_entry_section.dart';
import 'package:mobile/features/transactions/presentation/widgets/transaction_icon.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The data of one transaction and, below it, the planned entry matched with
/// it (read only: there is no way to link or unlink yet).
class TransactionDetailView extends StatelessWidget {
  const TransactionDetailView({
    super.key,
    required this.args,
    required this.createLinkedViewModel,
  });

  /// Builds the ViewModel of the "Lançamento vinculado" block.
  final LinkedEntriesViewModel Function(String transactionId)
  createLinkedViewModel;

  /// `null` when the screen was opened without the transaction (for example
  /// after the app was restored). It then says so and goes back to the list.
  final TransactionDetailArgs? args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final args = this.args;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.detailTitle)),
      body: args == null
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.detailMissing,
              action: OutlinedButton(
                onPressed: () => context.go(AppRoutes.transactions),
                child: Text(l10n.detailBack),
              ),
            )
          : _Content(args: args, createLinkedViewModel: createLinkedViewModel),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.args, required this.createLinkedViewModel});

  final TransactionDetailArgs args;
  final LinkedEntriesViewModel Function(String transactionId)
  createLinkedViewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TallyColors.of(context);
    final transaction = args.transaction;
    final account = args.account;
    final owner = args.owner;
    final description = transaction.description?.trim();
    final pending = transaction.isPending;

    final rows = <_DetailRow>[
      _DetailRow(l10n.detailDate, Text(DateFormatter.date(transaction.day))),
      _DetailRow(
        l10n.detailDescription,
        Text(
          description == null || description.isEmpty ? '—' : description,
          textAlign: TextAlign.end,
        ),
      ),
      if (transaction.category != null && transaction.category!.isNotEmpty)
        _DetailRow(
          l10n.detailCategory,
          Text(transaction.category!, textAlign: TextAlign.end),
        ),
      if (transaction.merchantName != null)
        _DetailRow(
          l10n.detailMerchant,
          Text(transaction.merchantName!, textAlign: TextAlign.end),
        ),
      if (account != null)
        _DetailRow(
          l10n.detailAccount,
          Text(
            '${account.displayName} ••${account.shortNumber}',
            textAlign: TextAlign.end,
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
              Text(owner.firstName),
            ],
          ),
        ),
      _DetailRow(
        l10n.detailType,
        Text(transaction.isIncome ? l10n.filterCredit : l10n.filterDebit),
      ),
      _DetailRow(
        l10n.detailStatus,
        Text(pending ? l10n.transactionPending : l10n.transactionPosted),
      ),
      _DetailRow(
        l10n.detailBalanceAfter,
        Text(
          transaction.balance == null
              ? '—'
              : MoneyFormatter.format(transaction.balance!),
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: [
        Column(
          children: [
            TransactionIcon(transaction: transaction, size: 56),
            const SizedBox(height: AppSpacing.sm),
            Text(
              MoneyFormatter.signed(
                transaction.absoluteAmount,
                isIncome: transaction.isIncome,
              ),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: transaction.isIncome ? colors.income : colors.expense,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              description == null || description.isEmpty
                  ? l10n.transactionsNoDescription
                  : description,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: pending
                    ? colors.warningContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                pending ? l10n.transactionPending : l10n.transactionPosted,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: pending ? colors.warning : scheme.onSurfaceVariant,
                ),
              ),
            ),
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
        LinkedEntrySection(
          transactionId: transaction.id,
          createViewModel: createLinkedViewModel,
        ),
      ],
    );
  }
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
