import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/presentation/widgets/chat_markdown.dart';

import '../../../support/pump_app.dart';

void main() {
  group('alignNumericColumns', () {
    test('right_aligns_columns_with_only_amounts_and_numbers', () {
      const table =
          '| Categoria | Valor | Parcelas |\n'
          '| --- | --- | --- |\n'
          '| Mercado | R\$ 1.234,56 | 3 |\n'
          '| Lazer | -R\$ 80,00 | 12 |';

      final result = alignNumericColumns(table).split('\n')[1];

      expect(result, '| --- | ---: | ---: |');
    });

    test('percentages_and_bold_numbers_count_as_numeric', () {
      const table = '| A | B |\n|---|---|\n| x | **45,5%** |\n| y | 10% |';

      expect(alignNumericColumns(table).split('\n')[1], '| --- | ---: |');
    });

    test('a_column_with_text_stays_left_aligned', () {
      const table = '| A | B |\n|---|---|\n| x | 10 |\n| y | n/a |';

      expect(alignNumericColumns(table).split('\n')[1], '|---|---|');
    });

    test('an_alignment_the_model_wrote_is_kept', () {
      const table = '| A | B |\n|:---|:---:|\n| 1 | 2 |';

      expect(alignNumericColumns(table).split('\n')[1], '|:---|:---:|');
    });

    test('text_without_tables_is_unchanged', () {
      const text = 'Olá\n\n- um\n- dois\n\n---\n\n**fim**';

      expect(alignNumericColumns(text), text);
    });
  });

  group('ChatMarkdown', () {
    testWidgets('renders_bold_lists_and_a_table_with_right_aligned_numbers', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const ChatMarkdown(
          data:
              'Total **R\$ 10,00**\n\n- item um\n- item dois\n\n'
              '| Categoria | Valor |\n| --- | --- |\n| Mercado | 10,00 |',
        ),
      );

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(
        find.textContaining('item um', findRichText: true),
        findsOneWidget,
      );
      final cell = find.text('10,00', findRichText: true);
      expect(cell, findsOneWidget);
      final align = tester.widget<DefaultTextStyle>(
        find.ancestor(of: cell, matching: find.byType(DefaultTextStyle)).first,
      );
      expect(align.textAlign, TextAlign.right);
    });
  });
}
