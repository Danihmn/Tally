import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "A conversa está chegando ao limite…", from 80% of the token limit.
class TokenWarningBanner extends StatelessWidget {
  const TokenWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = TallyColors.of(context);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        0,
        AppSpacing.screenGutter,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.warning, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              AppLocalizations.of(context).chatWarning,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// Replaces the composer when the conversation is full.
class ConversationFullBar extends StatelessWidget {
  const ConversationFullBar({super.key, required this.onStartNew});

  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.chatFullTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.chatFullMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: onStartNew,
          icon: const Icon(Icons.add_comment_outlined),
          label: Text(l10n.chatStartNew),
        ),
      ],
    );
  }
}
