import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// One account or card: icon, name, "Conta •••• 1234", the owner, the balance
/// (or the open bill) and, for a card, how much of the limit is used. Tapping
/// it opens the transactions of that account.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.ownerInitial,
    required this.ownerColor,
    required this.onTap,
  });

  final AccountBalance account;
  final String ownerInitial;
  final Color ownerColor;
  final VoidCallback onTap;

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
                        Text(
                          account.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
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
                isCard ? l10n.accountBillLabel : l10n.accountBalanceLabel,
                style: muted,
              ),
              Text(
                balance == null ? '—' : MoneyFormatter.format(balance),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isCard && balance != null)
                _CardUsage(credit: account.credit, balance: balance),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.accountSeeTransactions,
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
          Text(
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
