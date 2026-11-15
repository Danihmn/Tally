import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/chat/presentation/widgets/chat_markdown.dart';
import 'package:mobile/l10n/app_localizations.dart';

const _bubbleRadius = Radius.circular(18);
const _cornerRadius = Radius.circular(4);

/// The user's message: right side, primary color.
class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.82,
        alignment: Alignment.centerRight,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: _bubbleRadius,
                topRight: _bubbleRadius,
                bottomLeft: _bubbleRadius,
                bottomRight: _cornerRadius,
              ),
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bubble of the assistant: left side, outlined, with [child] inside.
class _AssistantFrame extends StatelessWidget {
  const _AssistantFrame({required this.child, this.errorStyle = false});

  final Widget child;
  final bool errorStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.94,
        alignment: Alignment.centerLeft,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(
                color: errorStyle ? scheme.error : scheme.outlineVariant,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: _bubbleRadius,
                topRight: _bubbleRadius,
                bottomLeft: _cornerRadius,
                bottomRight: _bubbleRadius,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The answer of Tally IA, rendered as markdown.
class AssistantBubble extends StatelessWidget {
  const AssistantBubble({super.key, required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) =>
      _AssistantFrame(child: ChatMarkdown(data: markdown));
}

/// Three dots and a caption while the first words of the answer are awaited.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return _AssistantFrame(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(
                        alpha: 0.35 + 0.65 * _phase(_controller.value, i),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              AppLocalizations.of(context).chatTyping,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// 0..1, a wave that reaches each dot a bit later than the previous one.
  double _phase(double t, int index) {
    final x = (t - index * 0.18) % 1.0;
    return x < 0.5 ? x * 2 : (1 - x) * 2;
  }
}

/// The question failed: message and "Tentar de novo".
class ErrorBubble extends StatelessWidget {
  const ErrorBubble({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _AssistantFrame(
      errorStyle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.chatErrorMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.chatErrorRetry),
          ),
        ],
      ),
    );
  }
}
