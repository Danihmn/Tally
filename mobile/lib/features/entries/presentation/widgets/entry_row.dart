import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_icon.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_status.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The text under the description: "Categoria · Débito · Despesa".
String entrySubtitle(AppLocalizations l10n, FinancialEntry entry) {
  final category = entry.category?.trim();
  return [
    if (category != null && category.isNotEmpty) category,
    ?switch (entry.paymentType) {
      PaymentType.debit => l10n.entryPayDebit,
      PaymentType.credit => l10n.entryPayCredit,
      null => null,
    },
    entry.isRevenue ? l10n.entryTypeRevenue : l10n.entryTypeExpense,
  ].join(' · ');
}

/// "Venc. 20/11 · Ref. nov." (the due date is left out when there is none).
String entryDatesLine(AppLocalizations l10n, FinancialEntry entry) {
  final due = entry.dueDate;
  return [
    if (due != null) l10n.entryDue(DateFormatter.dayMonth(due)),
    l10n.entryRef(DateFormatter.monthShort(entry.referenceMonth)),
  ].join(' · ');
}

/// One entry of the list: icon, description, category and payment, due date and
/// month, an installment tag, the signed amount and the status.
class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.entry,
    required this.today,
    required this.onTap,
  });

  final FinancialEntry entry;
  final DateTime today;
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
    final installment = entry.installmentLabel;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              EntryIcon(entry: entry),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EllipsisText(
                      entry.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    EllipsisText(entrySubtitle(l10n, entry), style: muted),
                    Row(
                      children: [
                        Flexible(
                          child: EllipsisText(
                            entryDatesLine(l10n, entry),
                            style: muted,
                          ),
                        ),
                        if (installment != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: EllipsisText(
                              installment,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  EllipsisText(
                    MoneyFormatter.signed(
                      entry.amount,
                      isIncome: entry.isRevenue,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: entry.isRevenue ? colors.income : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  EntryStatusBadge(badge: entryBadge(entry, today)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
