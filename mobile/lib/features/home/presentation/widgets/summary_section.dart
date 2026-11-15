import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/features/home/domain/entities/spending_summary.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The big number of the month (what was spent) and the two small cards
/// under it (received and balance).
class SummarySection extends StatelessWidget {
  const SummarySection({
    super.key,
    required this.summary,
    required this.month,
    required this.isCurrentMonth,
    required this.lastClosedDay,
  });

  final SpendingSummary summary;
  final DateTime month;
  final bool isCurrentMonth;

  /// The last day with numbers, or `null` when no day is over yet.
  final DateTime? lastClosedDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TallyColors.of(context);
    final average = MoneyFormatter.format(summary.averagePerDay);
    final day = lastClosedDay;
    final sub = day == null
        ? l10n.homeNoSpendYet
        : isCurrentMonth
        ? l10n.homeAverageUntil(average, DateFormatter.dayMonth(day))
        : l10n.homeAverage(average);
    final positive = summary.balance >= Decimal.zero;
    final onPrimary = scheme.onPrimary;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EllipsisText(
                l10n.homeSpentIn(DateFormatter.monthName(month)),
                style: theme.textTheme.bodyMedium?.copyWith(color: onPrimary),
              ),
              const SizedBox(height: AppSpacing.xxs),
              EllipsisText(
                MoneyFormatter.format(summary.spent),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              EllipsisText(
                sub,
                style: theme.textTheme.bodySmall?.copyWith(color: onPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                icon: Icons.south_west_rounded,
                label: l10n.homeReceived,
                value: MoneyFormatter.format(summary.received),
                color: colors.income,
                background: colors.incomeContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MiniCard(
                icon: Icons.balance_rounded,
                label: l10n.homeBalance,
                value: MoneyFormatter.signed(
                  summary.balance,
                  isIncome: positive,
                ),
                color: positive ? colors.income : colors.expense,
                background: positive
                    ? colors.incomeContainer
                    : colors.expenseContainer,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: EllipsisText(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            EllipsisText(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
