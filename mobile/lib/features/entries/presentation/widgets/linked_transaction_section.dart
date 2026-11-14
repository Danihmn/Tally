import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/entries/presentation/viewmodels/linked_transactions_view_model.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/presentation/views/transaction_detail_args.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "Transação do banco": the bank transaction matched with a reconciled entry
/// (read only). It loads by itself: while it loads, or if it fails, the rest
/// of the detail screen stays as it is.
class LinkedTransactionSection extends StatefulWidget {
  const LinkedTransactionSection({
    super.key,
    required this.entryId,
    required this.createViewModel,
    this.onOpenTransaction,
  });

  final String entryId;
  final LinkedTransactionsViewModel Function(String entryId) createViewModel;

  /// Defaults to opening the transaction detail with the router.
  final ValueChanged<TransactionDetailArgs>? onOpenTransaction;

  @override
  State<LinkedTransactionSection> createState() =>
      _LinkedTransactionSectionState();
}

class _LinkedTransactionSectionState extends State<LinkedTransactionSection> {
  late final LinkedTransactionsViewModel _viewModel = widget.createViewModel(
    widget.entryId,
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

  void _open(Transaction transaction) {
    final vm = _viewModel;
    final args = TransactionDetailArgs(
      transaction: transaction,
      account: vm.accountOf(transaction.accountId),
      owner: vm.memberOf(transaction.ownerId),
      ownerColorIndex: vm.memberIndexOf(transaction.ownerId),
    );
    final open = widget.onOpenTransaction;
    if (open != null) {
      open(args);
    } else {
      unawaited(context.push(AppRoutes.transactionDetail, extra: args));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.link_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              l10n.linkedTransactionTitle,
              style: theme.textTheme.titleMedium,
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
      case UiInitial<List<Transaction>>() || UiLoading<List<Transaction>>():
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Skeleton(height: 40),
          ),
        );
      case UiError<List<Transaction>>():
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
      case UiEmpty<List<Transaction>>():
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(l10n.linkedTransactionNone, style: muted),
          ),
        );
      case UiSuccess<List<Transaction>>(:final data):
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < data.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _LinkedTransactionTile(
                  transaction: data[i],
                  accountName: _viewModel
                      .accountOf(data[i].accountId)
                      ?.displayName,
                  onTap: () => _open(data[i]),
                ),
              ],
            ],
          ),
        );
    }
  }
}

class _LinkedTransactionTile extends StatelessWidget {
  const _LinkedTransactionTile({
    required this.transaction,
    required this.accountName,
    required this.onTap,
  });

  final Transaction transaction;
  final String? accountName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = TallyColors.of(context);
    final description = transaction.description?.trim();
    final meta = [
      DateFormatter.date(transaction.day),
      ?accountName,
    ].join(' · ');
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
                  Text(
                    description == null || description.isEmpty
                        ? l10n.transactionsNoDescription
                        : description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              MoneyFormatter.signed(
                transaction.absoluteAmount,
                isIncome: transaction.isIncome,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: transaction.isIncome ? colors.income : null,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
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
