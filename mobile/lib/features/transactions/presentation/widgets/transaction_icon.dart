import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';

/// The round icon of a transaction. The group of the category (the first two
/// digits of `categoryId`) picks the icon when it is a group we know; for any
/// other the icon only says whether the money came in or went out.
class TransactionIcon extends StatelessWidget {
  const TransactionIcon({super.key, required this.transaction, this.size = 40});

  final Transaction transaction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = TallyColors.of(context);
    final categoryId = transaction.categoryId;
    final group = categoryId != null && categoryId.length >= 2
        ? categoryId.substring(0, 2)
        : null;
    final (icon, color) = switch (group) {
      '01' => (Icons.payments_outlined, colors.income),
      '05' => (Icons.swap_horiz_rounded, const Color(0xFF5B6EE1)),
      '19' => (Icons.directions_car_outlined, const Color(0xFFE08A1E)),
      _ =>
        transaction.isIncome
            ? (Icons.south_west_rounded, colors.income)
            : (Icons.north_east_rounded, colors.expense),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}
