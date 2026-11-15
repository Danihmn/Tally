import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';

/// Marks the numeric columns of every markdown table as right-aligned, as in
/// the design. A model rarely writes the `---:` alignment itself, so this
/// adds it for columns whose cells are all amounts, numbers or percentages.
/// A column that already has an alignment is left as it is.
String alignNumericColumns(String markdown) {
  final lines = markdown.split('\n');
  for (var i = 1; i < lines.length; i++) {
    if (!_isDelimiterRow(lines[i]) || !lines[i - 1].contains('|')) continue;
    final delimiter = _cells(lines[i]);
    final rows = <List<String>>[];
    var end = i + 1;
    while (end < lines.length && lines[end].contains('|')) {
      rows.add(_cells(lines[end]));
      end++;
    }
    var changed = false;
    for (var c = 0; c < delimiter.length; c++) {
      if (delimiter[c].contains(':')) continue;
      final values = [
        for (final row in rows)
          if (c < row.length && row[c].isNotEmpty) row[c],
      ];
      if (values.isNotEmpty && values.every(_isNumeric)) {
        delimiter[c] = '---:';
        changed = true;
      }
    }
    if (changed) lines[i] = '| ${delimiter.join(' | ')} |';
  }
  return lines.join('\n');
}

final _delimiterRow = RegExp(
  r'^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*$',
);
final _numeric = RegExp(r'^[-−+]?\s*(R\$)?\s*[-−+]?\s*\d[\d.,]*\s*%?$');

bool _isDelimiterRow(String line) =>
    line.contains('-') && _delimiterRow.hasMatch(line);

bool _isNumeric(String cell) =>
    _numeric.hasMatch(cell.replaceAll('*', '').trim());

List<String> _cells(String line) {
  var text = line.trim();
  if (text.startsWith('|')) text = text.substring(1);
  if (text.endsWith('|')) text = text.substring(0, text.length - 1);
  return [for (final cell in text.split('|')) cell.trim()];
}

/// The answer of the assistant: markdown (paragraphs, lists, tables, bold)
/// styled from the theme.
class ChatMarkdown extends StatelessWidget {
  const ChatMarkdown({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurface);
    final sheet = MarkdownStyleSheet(
      p: body,
      pPadding: EdgeInsets.zero,
      strong: body.copyWith(fontWeight: FontWeight.w700),
      em: body.copyWith(fontStyle: FontStyle.italic),
      listBullet: body,
      listIndent: AppSpacing.md,
      blockSpacing: AppSpacing.xs,
      h1: theme.textTheme.titleMedium,
      h2: theme.textTheme.titleMedium,
      h3: theme.textTheme.titleSmall,
      code: body.copyWith(
        backgroundColor: scheme.surfaceContainerHighest,
        fontFamily: 'monospace',
      ),
      tableHead: theme.textTheme.labelMedium!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      tableBody: body.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      tableHeadAlign: TextAlign.left,
      tableBorder: TableBorder(
        horizontalInside: BorderSide(color: scheme.outlineVariant),
        top: BorderSide(color: scheme.outlineVariant),
        bottom: BorderSide(color: scheme.outlineVariant),
      ),
      tableColumnWidth: const IntrinsicColumnWidth(),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
    );
    final aligned = alignNumericColumns(data);
    return MarkdownBody(
      data: aligned,
      styleSheet: sheet,
      shrinkWrap: true,
      softLineBreak: true,
      // A wide table scrolls sideways inside the bubble.
      fitContent: true,
    );
  }
}
