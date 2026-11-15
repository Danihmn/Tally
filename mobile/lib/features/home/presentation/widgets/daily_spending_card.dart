import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/features/home/domain/entities/daily_amount.dart';
import 'package:mobile/features/home/domain/entities/month_period.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// One bar for each day of the month. Days that are not over yet are small
/// gray bars.
class DailySpendingCard extends StatelessWidget {
  const DailySpendingCard({
    super.key,
    required this.days,
    required this.period,
    required this.lastClosedDay,
    required this.average,
  });

  final List<DailyAmount> days;
  final MonthPeriod period;

  /// The last day with numbers, or `null` when no day is over yet.
  final DateTime? lastClosedDay;
  final Decimal average;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final amountOf = {for (final d in days) d.day.day: d.amount};
    final biggest = days.fold<Decimal>(
      Decimal.zero,
      (max, d) => d.amount > max ? d.amount : max,
    );
    final lastDay = period.daysInMonth;
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    Widget bar(int day) {
      final closed = lastClosedDay != null && day <= lastClosedDay!.day;
      double factor = 0.02;
      Color color = scheme.surfaceContainerHigh;
      if (closed) {
        final amount = amountOf[day] ?? Decimal.zero;
        factor = biggest > Decimal.zero
            ? (amount / biggest).toDouble().clamp(0.03, 1.0)
            : 0.03;
        color = scheme.primary;
      }
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: factor,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.dailyTitle, style: theme.textTheme.titleMedium),
                EllipsisText(
                  l10n.dailyAverage(MoneyFormatter.format(average)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: l10n.dailyChartLabel,
              child: SizedBox(
                height: 112,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (var day = 1; day <= lastDay; day++) bar(day)],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1', style: axisStyle),
                Text('10', style: axisStyle),
                Text('20', style: axisStyle),
                Text('$lastDay', style: axisStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
