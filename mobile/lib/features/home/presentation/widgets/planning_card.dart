import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/features/home/domain/entities/planning_progress.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "Planned against real": the planned expenses, how much is already
/// reconciled with the bank, and how many entries are reconciled.
class PlanningCard extends StatelessWidget {
  const PlanningCard({super.key, required this.progress, required this.month});

  final PlanningProgress progress;
  final DateTime month;

  /// `nov/26`.
  String get _monthShort =>
      '${DateFormatter.monthName(month).substring(0, 3)}/'
      '${(month.year % 100).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = TallyColors.of(context);
    final percent = (progress.ratio * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.planningTitle, style: theme.textTheme.titleMedium),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_monthShort, style: theme.textTheme.labelSmall),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _Amount(
                    label: l10n.planningPlanned,
                    value: MoneyFormatter.format(progress.planned),
                  ),
                ),
                Expanded(
                  child: _Amount(
                    label: l10n.planningReal,
                    value: MoneyFormatter.format(progress.reconciled),
                    color: colors.income,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: l10n.planningBarLabel,
              value: '$percent%',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress.ratio,
                  minHeight: 10,
                  color: colors.income,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            EllipsisText(
              l10n.planningCount(progress.reconciledCount, progress.totalCount),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EllipsisText(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        EllipsisText(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
