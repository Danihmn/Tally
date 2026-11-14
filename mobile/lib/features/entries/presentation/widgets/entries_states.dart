import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The tab has no entries. With a search text or filters it offers to clear
/// them. [month] is the month on screen (`null` for every month).
class EntriesEmptyCard extends StatelessWidget {
  const EntriesEmptyCard({
    super.key,
    required this.tab,
    required this.month,
    required this.filtered,
    required this.onClearAll,
  });

  final EntryStatus tab;
  final DateTime? month;
  final bool filtered;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final base = switch (tab) {
      EntryStatus.planned => l10n.entriesEmptyTitlePlanned,
      EntryStatus.reconciled => l10n.entriesEmptyTitleReconciled,
      EntryStatus.cancelled => l10n.entriesEmptyTitleCancelled,
    };
    final month = this.month;
    final title = month == null
        ? base
        : l10n.entriesEmptyInMonth(
            base,
            DateFormatter.monthName(month).toLowerCase(),
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
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
              filtered ? l10n.entriesEmptyFiltered : l10n.entriesEmptyPlain,
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
