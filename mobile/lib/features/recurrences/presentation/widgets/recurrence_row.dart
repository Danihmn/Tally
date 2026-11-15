import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// What the row menu can do with a recurrence.
enum RecurrenceAction { edit, delete }

/// The text under the description: "Categoria · Débito · Despesa".
String recurrenceSubtitle(AppLocalizations l10n, Recurrence recurrence) {
  final category = recurrence.category?.trim();
  return [
    if (category != null && category.isNotEmpty) category,
    ?switch (recurrence.paymentType) {
      PaymentType.debit => l10n.entryPayDebit,
      PaymentType.credit => l10n.entryPayCredit,
      null => null,
    },
    recurrence.isRevenue ? l10n.entryTypeRevenue : l10n.entryTypeExpense,
  ].join(' · ');
}

/// One recurrence of the list: icon, description, category and payment, the
/// day of the month, the signed amount and a menu to edit or delete it.
class RecurrenceRow extends StatelessWidget {
  const RecurrenceRow({
    super.key,
    required this.recurrence,
    required this.onAction,
  });

  final Recurrence recurrence;
  final ValueChanged<RecurrenceAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = TallyColors.of(context);
    final color = recurrence.isRevenue ? colors.income : colors.expense;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final day = recurrence.dueDay;
    return InkWell(
      onTap: () => onAction(RecurrenceAction.edit),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.event_repeat_rounded, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EllipsisText(
                      recurrence.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    EllipsisText(
                      recurrenceSubtitle(l10n, recurrence),
                      style: muted,
                    ),
                    EllipsisText(
                      day == null
                          ? l10n.recurrenceNoDay
                          : l10n.recurrenceDay(day),
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              EllipsisText(
                MoneyFormatter.signed(
                  recurrence.amount,
                  isIncome: recurrence.isRevenue,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: recurrence.isRevenue ? colors.income : null,
                ),
              ),
              PopupMenuButton<RecurrenceAction>(
                tooltip: recurrence.description,
                onSelected: onAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: RecurrenceAction.edit,
                    child: Text(l10n.entryActionEdit),
                  ),
                  PopupMenuItem(
                    value: RecurrenceAction.delete,
                    child: Text(l10n.recurrenceDeleteAction),
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
