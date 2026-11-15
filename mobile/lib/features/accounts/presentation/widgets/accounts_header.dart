import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "Saldo total em contas" and, under it, the open bills of the cards. Each
/// total has its own state: a failed one only shows "—" and a retry.
class AccountsHeader extends StatelessWidget {
  const AccountsHeader({
    super.key,
    required this.bankTotal,
    required this.cardTotal,
    required this.hasCards,
    required this.onRetry,
  });

  final UiState<Decimal> bankTotal;
  final UiState<Decimal> cardTotal;

  /// Whether the person has any card (otherwise "Sem cartões conectados").
  final bool hasCards;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onPrimary = scheme.onPrimary;
    final failed =
        bankTotal is UiError<Decimal> || cardTotal is UiError<Decimal>;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.accountsTotalTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          _amount(
            bankTotal,
            theme.textTheme.headlineMedium?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.w600,
            ),
            onPrimary,
          ),
          const SizedBox(height: AppSpacing.xs),
          _bills(l10n, theme, onPrimary),
          if (failed) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.accountsTotalsError,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(foregroundColor: onPrimary),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _amount(UiState<Decimal> state, TextStyle? style, Color color) =>
      switch (state) {
        UiSuccess<Decimal>(:final data) => EllipsisText(
          MoneyFormatter.format(data),
          style: style,
        ),
        UiError<Decimal>() => Text('—', style: style),
        _ => _Placeholder(width: 160, height: 32, color: color),
      };

  Widget _bills(AppLocalizations l10n, ThemeData theme, Color onPrimary) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: onPrimary.withValues(alpha: 0.8),
    );
    if (!hasCards) return Text(l10n.accountsNoCards, style: style);
    return switch (cardTotal) {
      UiSuccess<Decimal>(:final data) => EllipsisText(
        l10n.accountsBills(MoneyFormatter.format(data)),
        style: style,
      ),
      UiError<Decimal>() => Text(l10n.accountsBills('—'), style: style),
      _ => _Placeholder(width: 200, height: 14, color: onPrimary),
    };
  }
}

/// A pale bar shown on the colored header while a total loads.
class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
