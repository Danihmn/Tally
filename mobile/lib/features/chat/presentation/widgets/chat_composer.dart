import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The text field, the send button, the character counter and the caption.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.enabled,
    this.maxLength = 2000,
  });

  /// The counter appears from here (the design shows it at 1700/2000).
  static const counterFrom = 1700;

  /// The counter turns to a warning from here.
  static const counterWarnFrom = 1900;

  final ValueChanged<String> onSend;

  /// False while an answer streams: the field stays, sending is off.
  final bool enabled;
  final int maxLength;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend =>
      widget.enabled &&
      _controller.text.trim().isNotEmpty &&
      _controller.text.length <= widget.maxLength;

  void _submit() {
    if (!_canSend) return;
    final text = _controller.text;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final length = _controller.text.length;
        final showCounter = length >= ChatComposer.counterFrom;
        final warn = length >= ChatComposer.counterWarnFrom;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: l10n.chatInputHint,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton.filled(
                    tooltip: l10n.chatSend,
                    onPressed: _canSend ? _submit : null,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ],
            ),
            if (showCounter)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  l10n.chatCounter(length, widget.maxLength),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: warn
                        ? TallyColors.of(context).warning
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Column(
                children: [
                  Text(
                    l10n.chatCaption,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    l10n.chatHistorySaved,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
