import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/presentation/widgets/transaction_icon.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// One transaction of the list: icon, description, "merchant · account", the
/// category and the status, the signed amount and the owner.
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    required this.accountName,
    required this.ownerInitial,
    required this.ownerColor,
    required this.onTap,
  });

  final Transaction transaction;
  final String? accountName;
  final String ownerInitial;
  final Color ownerColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TallyColors.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final description = transaction.description?.trim();
    final sub = [?transaction.merchantName, ?accountName].join(' · ');
    final category = transaction.category?.trim();
    final pending = transaction.isPending;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              TransactionIcon(transaction: transaction),
              const SizedBox(width: AppSpacing.sm),
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
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 4,
                      children: [
                        if (category != null && category.isNotEmpty)
                          _Tag(
                            text: category,
                            background: scheme.surfaceContainerHighest,
                            foreground: scheme.onSurfaceVariant,
                          ),
                        _Tag(
                          text: pending
                              ? l10n.transactionPending
                              : l10n.transactionPosted,
                          background: pending
                              ? colors.warningContainer
                              : scheme.surfaceContainerHighest,
                          foreground: pending
                              ? colors.warning
                              : scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                  const SizedBox(height: 6),
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: ownerColor.withValues(alpha: 0.18),
                    child: Text(
                      ownerInitial,
                      style: TextStyle(fontSize: 11, color: ownerColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}
