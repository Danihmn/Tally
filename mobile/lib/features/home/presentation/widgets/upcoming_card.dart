import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/features/home/domain/entities/upcoming_entry.dart';
import 'package:mobile/features/home/presentation/widgets/category_style.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The entries that fall due soon: icon of the category, description, day,
/// amount and when it is due.
class UpcomingCard extends StatelessWidget {
  const UpcomingCard({
    super.key,
    required this.entries,
    required this.today,
    required this.onSeeAll,
  });

  /// How many entries the card shows.
  static const maxShown = 4;

  final List<UpcomingEntry> entries;
  final DateTime today;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.upcomingTitle, style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: onSeeAll,
                  child: Text(l10n.upcomingSeeAll),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Text(
                l10n.upcomingEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final entry in entries.take(maxShown))
              _UpcomingRow(entry: entry, today: today),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.entry, required this.today});

  final UpcomingEntry entry;
  final DateTime today;

  /// Whole calendar days from [today] to the due date.
  int get _days => DateTime.utc(
    entry.dueDate.year,
    entry.dueDate.month,
    entry.dueDate.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TallyColors.of(context);
    final style = categoryStyle(entry.category, scheme.onSurfaceVariant);
    final category = entry.category;
    final days = _days;
    final soon = days <= 3;
    final when = days <= 0 ? l10n.upcomingToday : l10n.upcomingInDays(days);
    final detail = category == null || category.isEmpty
        ? DateFormatter.dayMonth(entry.dueDate)
        : '${DateFormatter.dayMonth(entry.dueDate)} · $category';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(style.icon, size: 20, color: style.color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EllipsisText(
                  entry.description,
                  style: theme.textTheme.bodyMedium,
                ),
                EllipsisText(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              EllipsisText(
                MoneyFormatter.signed(entry.amount, isIncome: entry.isIncome),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: entry.isIncome ? colors.income : null,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: soon
                      ? colors.warningContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: EllipsisText(
                  when,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: soon ? colors.warning : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
