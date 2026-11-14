import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The text of the chip of one filter, for example "Despesas" or "Venc. de 01/11".
String entryFilterChipLabel(
  AppLocalizations l10n,
  EntryFilterKey key,
  EntryFilters filters,
  List<BankAccount> accounts,
) {
  switch (key) {
    case EntryFilterKey.account:
      for (final account in accounts) {
        if (account.id == filters.accountId) return account.displayName;
      }
      return l10n.filterAccount;
    case EntryFilterKey.type:
      return filters.type == EntryType.revenues
          ? l10n.chipRevenues
          : l10n.chipExpenses;
    case EntryFilterKey.paymentType:
      return filters.paymentType == PaymentType.credit
          ? l10n.entryPayCredit
          : l10n.entryPayDebit;
    case EntryFilterKey.dueFrom:
      return l10n.chipDueFrom(DateFormatter.dayMonth(filters.dueFrom!));
    case EntryFilterKey.dueTo:
      return l10n.chipDueTo(DateFormatter.dayMonth(filters.dueTo!));
    case EntryFilterKey.minAmount:
      return l10n.chipMin(MoneyFormatter.format(filters.minAmount!));
    case EntryFilterKey.maxAmount:
      return l10n.chipMax(MoneyFormatter.format(filters.maxAmount!));
  }
}

/// A row of chips, one for each filter in use. Tapping the x of a chip removes
/// that filter.
class EntryFilterChips extends StatelessWidget {
  const EntryFilterChips({
    super.key,
    required this.filters,
    required this.accounts,
    required this.onRemove,
  });

  final EntryFilters filters;
  final List<BankAccount> accounts;
  final ValueChanged<EntryFilterKey> onRemove;

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
                label: Text(entryFilterChipLabel(l10n, key, filters, accounts)),
                deleteButtonTooltipMessage: l10n.transactionsRemoveFilter(
                  entryFilterChipLabel(l10n, key, filters, accounts),
                ),
                onDeleted: () => onRemove(key),
              ),
            ),
        ],
      ),
    );
  }
}
