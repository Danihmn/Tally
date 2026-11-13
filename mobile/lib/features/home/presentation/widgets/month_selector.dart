import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "Novembro 2026" with the arrows to go to the previous and the next month.
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.month,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = DateFormatter.monthName(month);
    final label = '${name[0].toUpperCase()}${name.substring(1)} ${month.year}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: l10n.monthPrevious,
          onPressed: canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(label, style: Theme.of(context).textTheme.titleLarge),
        IconButton(
          tooltip: l10n.monthNext,
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
