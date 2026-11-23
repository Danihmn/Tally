import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// One account or card: icon, name, "Conta •••• 1234", the owner, the balance
/// (for a card, the bill due next month) and, for a card, how much of the
/// limit is used (from the whole used limit, not the bill). Tapping an account
/// opens its transactions; tapping a card opens its bill. A bank account also has the
/// "Conta salário" switch when [onSalaryAccountChanged] is given.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.ownerInitial,
    required this.ownerColor,
    required this.onTap,
    this.onSalaryAccountChanged,
    this.onEditBankCode,
    this.saving = false,
  });

  final AccountBalance account;
  final String ownerInitial;
  final Color ownerColor;
  final VoidCallback onTap;

  /// Called with the new value of the switch. `null` hides the switch.
  final ValueChanged<bool>? onSalaryAccountChanged;

  /// Opens the bank code of a salary account to be corrected.
  final VoidCallback? onEditBankCode;

  /// The settings are being saved: the switch is disabled meanwhile.
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final isCard = account.isCreditCard;
    final balance = account.balance;
    final nextBill = account.nextBill;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: ownerColor.withValues(alpha: 0.14),
                    child: Icon(
                      isCard
                          ? Icons.credit_card_rounded
                          : Icons.account_balance_rounded,
                      size: 20,
                      color: ownerColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EllipsisText(
                          account.displayName,
                          style: theme.textTheme.titleSmall,
                        ),
                        EllipsisText(
                          isCard
                              ? l10n.accountSubCard(account.shortNumber)
                              : l10n.accountSubBank(account.shortNumber),
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: ownerColor.withValues(alpha: 0.18),
                    child: Text(
                      ownerInitial,
                      style: TextStyle(fontSize: 11, color: ownerColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                !isCard
                    ? l10n.accountBalanceLabel
                    : nextBill == null
                    ? l10n.accountNextBillLabelGeneric
                    : l10n.accountNextBillLabel(
                        DateFormatter.monthName(nextBill.month),
                      ),
                style: muted,
              ),
              EllipsisText(
                switch (isCard ? nextBill?.total : balance) {
                  final Decimal value => MoneyFormatter.format(value),
                  null => '—',
                },
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isCard && balance != null)
                _CardUsage(credit: account.credit, balance: balance),
              if (!isCard && onSalaryAccountChanged != null)
                _SalaryAccountRow(
                  account: account,
                  saving: saving,
                  onChanged: onSalaryAccountChanged!,
                  onEditBankCode: onEditBankCode,
                ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isCard
                          ? l10n.accountSeeBill
                          : l10n.accountSeeTransactions,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Conta salário": the switch, what it means and the bank code when on.
class _SalaryAccountRow extends StatelessWidget {
  const _SalaryAccountRow({
    required this.account,
    required this.saving,
    required this.onChanged,
    this.onEditBankCode,
  });

  final AccountBalance account;
  final bool saving;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onEditBankCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final on = account.outgoingTransfersAreIncome;
    final code = account.bankCode;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.accountSalaryTitle,
                  style: theme.textTheme.labelLarge,
                ),
                Text(
                  on && code != null
                      ? '${l10n.accountSalaryText} · ${l10n.accountSalaryBank(code)}'
                      : l10n.accountSalaryText,
                  style: muted,
                ),
              ],
            ),
          ),
          if (on && onEditBankCode != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.accountSalaryEditCode,
              onPressed: saving ? null : onEditBankCode,
            ),
          Switch(value: on, onChanged: saving ? null : onChanged),
        ],
      ),
    );
  }
}

/// The bar and the line "Usado 30% · Limite R$ … · Disponível R$ …". It is
/// left out when the bank did not send the limit.
class _CardUsage extends StatelessWidget {
  const _CardUsage({required this.credit, required this.balance});

  final CreditInfo? credit;
  final Decimal balance;

  @override
  Widget build(BuildContext context) {
    final info = credit;
    final share = info?.usedShare(balance);
    if (info == null || share == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = share > 0.8
        ? scheme.error
        : share > 0.6
        ? Colors.orange
        : scheme.primary;
    final available = info.availableCreditLimit;
    final parts = [
      l10n.accountCardUsed((share * 100).round()),
      l10n.accountCardLimit(MoneyFormatter.format(info.creditLimit!)),
      if (available != null)
        l10n.accountCardAvailable(MoneyFormatter.format(available)),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          EllipsisText(
            parts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
