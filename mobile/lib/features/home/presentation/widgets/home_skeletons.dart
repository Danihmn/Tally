import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/widgets/skeleton.dart';

/// Placeholder of the top of the home (the big card and the two small ones),
/// with the sizes of the real cards, so nothing jumps when the numbers arrive.
class SummarySkeleton extends StatelessWidget {
  const SummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Skeleton(height: 128, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: Skeleton(height: 88, radius: AppRadius.card)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Skeleton(height: 88, radius: AppRadius.card)),
          ],
        ),
      ],
    );
  }
}

/// Placeholder of one card.
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) =>
      Skeleton(height: height, radius: AppRadius.card);
}
