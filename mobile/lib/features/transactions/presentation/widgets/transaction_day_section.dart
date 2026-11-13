import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_day_group.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "Hoje", "Ontem" or "Seg, 10/11", from a UTC calendar day and the day of
/// today (both at midnight).
String transactionDayLabel(
  AppLocalizations l10n,
  DateTime day,
  DateTime today,
) {
  final days = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  if (days == 0) return l10n.dayToday;
  if (days == 1) return l10n.dayYesterday;
  return '${DateFormatter.weekdayShort(day)}, ${DateFormatter.dayMonth(day)}';
}

/// A day of the list: its label, what the day added up to, and a card with
/// its transactions.
class TransactionDaySection extends StatelessWidget {
  const TransactionDaySection({
    super.key,
    required this.group,
    required this.today,
    required this.rowBuilder,
  });

  final TransactionDayGroup group;
  final DateTime today;
  final Widget Function(BuildContext context, int index) rowBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = group.total;
    final positive = total >= Decimal.zero;
    final muted = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            0,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(transactionDayLabel(l10n, group.day, today), style: muted),
              Text(
                MoneyFormatter.signed(total.abs(), isIncome: positive),
                style: muted,
              ),
            ],
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < group.items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                rowBuilder(context, i),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
