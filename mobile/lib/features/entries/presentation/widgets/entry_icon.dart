import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';

/// The round icon of an entry: money coming in or going out.
class EntryIcon extends StatelessWidget {
  const EntryIcon({super.key, required this.entry, this.size = 40});

  final FinancialEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = TallyColors.of(context);
    final color = entry.isRevenue ? colors.income : colors.expense;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: Icon(
        entry.isRevenue ? Icons.south_west_rounded : Icons.north_east_rounded,
        size: size * 0.5,
        color: color,
      ),
    );
  }
}
