import 'package:material_ui/material_ui.dart';

/// A text that never overflows: when it does not fit it ends with "..." and
/// pressing it shows a tooltip with the whole value. When it fits there is no
/// tooltip at all.
///
/// Use it for every text that comes from data (descriptions, names, accounts)
/// and for money, which would otherwise break at the space after "R$".
///
/// By default the tooltip opens with a long press, so a text inside a tappable
/// row does not steal the row's tap. Pass [tapToShow] for a text that is not
/// inside anything tappable, where a plain tap is the natural way to look.
class EllipsisText extends StatelessWidget {
  const EllipsisText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
    this.tapToShow = false,
  }) : assert(maxLines > 0, 'maxLines must be positive');

  final String text;
  final TextStyle? style;

  /// How many lines may show before the "...". Money and short labels keep 1.
  final int maxLines;
  final TextAlign? textAlign;

  /// Opens the tooltip with a tap instead of a long press.
  final bool tapToShow;

  @override
  Widget build(BuildContext context) {
    final shown = Text(
      text,
      style: style,
      maxLines: maxLines,
      // One line must not wrap at a space (the one after "R$" for example).
      softWrap: maxLines > 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_isCut(context, constraints.maxWidth)) return shown;
        return Tooltip(
          message: text,
          triggerMode: tapToShow
              ? TooltipTriggerMode.tap
              : TooltipTriggerMode.longPress,
          // The text itself is already read by screen readers.
          excludeFromSemantics: true,
          child: shown,
        );
      },
    );
  }

  /// Whether [text] does not fit in [maxWidth] with [maxLines] lines.
  bool _isCut(BuildContext context, double maxWidth) {
    if (!maxWidth.isFinite || text.isEmpty) return false;
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final painter = TextPainter(
      text: TextSpan(text: text, style: effective),
      maxLines: maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    try {
      if (maxLines == 1) {
        painter.layout();
        return painter.width > maxWidth + 0.5;
      }
      painter.layout(maxWidth: maxWidth);
      return painter.didExceedMaxLines;
    } finally {
      painter.dispose();
    }
  }
}
