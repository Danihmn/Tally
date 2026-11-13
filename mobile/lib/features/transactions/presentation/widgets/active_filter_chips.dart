import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The text of the chip of one filter, for example "Débitos" or "Mín. R$ 10,00".
String filterChipLabel(
  AppLocalizations l10n,
  TransactionFilterKey key,
  TransactionFilters filters,
  List<BankAccount> accounts,
) {
  switch (key) {
    case TransactionFilterKey.account:
      for (final account in accounts) {
        if (account.id == filters.accountId) return account.displayName;
      }
      return l10n.filterAccount;
    case TransactionFilterKey.direction:
      return filters.direction == TransactionDirection.credit
          ? l10n.chipCredits
          : l10n.chipDebits;
    case TransactionFilterKey.status:
      return filters.status == TransactionStatus.pending
          ? l10n.chipPending
          : l10n.chipPosted;
    case TransactionFilterKey.dateFrom:
      return l10n.chipFrom(DateFormatter.dayMonth(filters.dateFrom!));
    case TransactionFilterKey.dateTo:
      return l10n.chipTo(DateFormatter.dayMonth(filters.dateTo!));
    case TransactionFilterKey.minAmount:
      return l10n.chipMin(MoneyFormatter.format(filters.minAmount!));
    case TransactionFilterKey.maxAmount:
      return l10n.chipMax(MoneyFormatter.format(filters.maxAmount!));
  }
}

/// A row of chips, one for each filter in use. Tapping the x of a chip
/// removes that filter.
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.filters,
    required this.accounts,
    required this.onRemove,
  });

  final TransactionFilters filters;
  final List<BankAccount> accounts;
  final ValueChanged<TransactionFilterKey> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final key in filters.activeKeys)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: InputChip(
                label: Text(filterChipLabel(l10n, key, filters, accounts)),
                deleteButtonTooltipMessage: l10n.transactionsRemoveFilter(
                  filterChipLabel(l10n, key, filters, accounts),
                ),
                onDeleted: () => onRemove(key),
              ),
            ),
        ],
      ),
    );
  }
}
