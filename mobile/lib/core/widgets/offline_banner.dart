import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Warning strip shown when the last request failed for lack of connection
/// while old data is still on screen. It hides itself for any other failure.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.failure});

  final Failure? failure;

  @override
  Widget build(BuildContext context) {
    if (failure is! NetworkFailure) return const SizedBox.shrink();
    final colors = TallyColors.of(context);
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: colors.warning);
    return Container(
      width: double.infinity,
      color: colors.warningContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: colors.warning),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              AppLocalizations.of(context).offlineBanner,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
