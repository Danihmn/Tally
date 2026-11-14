import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// What the badge of an entry says: "Vencido" is a planned entry past its due
/// date, so it depends on today.
enum EntryBadge { planned, overdue, reconciled, cancelled }

EntryBadge entryBadge(FinancialEntry entry, DateTime today) =>
    switch (entry.status) {
      EntryStatus.reconciled => EntryBadge.reconciled,
      EntryStatus.cancelled => EntryBadge.cancelled,
      EntryStatus.planned =>
        entry.isOverdue(today) ? EntryBadge.overdue : EntryBadge.planned,
    };

/// The small colored label with the status of an entry.
class EntryStatusBadge extends StatelessWidget {
  const EntryStatusBadge({super.key, required this.badge});

  final EntryBadge badge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = TallyColors.of(context);
    final (text, background, foreground) = switch (badge) {
      EntryBadge.planned => (
        l10n.entryStatusPlanned,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      EntryBadge.overdue => (
        l10n.entryStatusOverdue,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      EntryBadge.reconciled => (
        l10n.entryStatusReconciled,
        colors.income.withValues(alpha: 0.14),
        colors.income,
      ),
      EntryBadge.cancelled => (
        l10n.entryStatusCancelled,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}
