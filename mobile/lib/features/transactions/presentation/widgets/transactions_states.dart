import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Placeholder of the list while the first page loads: a card of rows.
class TransactionsSkeleton extends StatelessWidget {
  const TransactionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < 6; i++)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Skeleton(width: 40, height: 40, radius: 20),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(height: 14),
                        SizedBox(height: AppSpacing.xs),
                        Skeleton(width: 120, height: 11),
                        SizedBox(height: AppSpacing.xs),
                        Skeleton(width: 70, height: 11),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Skeleton(width: 64, height: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The list is empty. With a search text or filters it offers to clear them.
class TransactionsEmptyCard extends StatelessWidget {
  const TransactionsEmptyCard({
    super.key,
    required this.filtered,
    required this.onClearAll,
  });

  final bool filtered;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.transactionsEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              filtered
                  ? l10n.transactionsEmptyFiltered
                  : l10n.transactionsEmptyPlain,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (filtered) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onClearAll,
                child: Text(l10n.transactionsClearAll),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The chosen person (or the house) has not connected a bank yet.
class NoBankCard extends StatelessWidget {
  const NoBankCard({super.key, required this.who, required this.onSeeAccounts});

  /// "A casa" or the first name of the person.
  final String who;
  final VoidCallback onSeeAccounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.transactionsNoBankTitle(who),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.transactionsNoBankMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onSeeAccounts,
              child: Text(l10n.transactionsSeeAccounts),
            ),
          ],
        ),
      ),
    );
  }
}
