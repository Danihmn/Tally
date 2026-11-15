import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';

import '../../support/pump_app.dart';

void main() {
  const long = 'Pagamento de uma descrição muito longa que não cabe na linha';

  Future<void> show(
    WidgetTester tester,
    Widget text, {
    double width = 160,
    VoidCallback? onTap,
  }) => pumpApp(
    tester,
    Center(
      child: SizedBox(
        width: width,
        child: InkWell(onTap: onTap, child: text),
      ),
    ),
  );

  group('EllipsisText', () {
    testWidgets('a_text_that_fits_has_no_tooltip', (tester) async {
      await show(tester, const EllipsisText('Mercado'));

      expect(find.byType(Tooltip), findsNothing);
      expect(find.text('Mercado'), findsOneWidget);
    });

    testWidgets('a_long_text_stays_on_one_line_and_ends_with_an_ellipsis', (
      tester,
    ) async {
      await show(tester, const EllipsisText(long));

      final text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(find.text(long)).height, lessThan(30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a_long_text_has_a_tooltip_with_the_whole_value', (
      tester,
    ) async {
      await show(tester, const EllipsisText(long));

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, long);
    });

    testWidgets('a_long_press_shows_the_tooltip', (tester) async {
      await show(tester, const EllipsisText(long));

      await tester.longPress(find.text(long));
      await tester.pumpAndSettle();

      expect(find.text(long), findsNWidgets(2));
    });

    testWidgets('a_tap_does_not_open_the_tooltip_and_still_reaches_the_row', (
      tester,
    ) async {
      var taps = 0;
      await show(tester, const EllipsisText(long), onTap: () => taps++);

      await tester.tap(find.text(long));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.text(long), findsOneWidget);
    });

    testWidgets('tap_to_show_opens_the_tooltip_with_a_tap', (tester) async {
      await show(tester, const EllipsisText(long, tapToShow: true));

      await tester.tap(find.text(long));
      await tester.pumpAndSettle();

      expect(find.text(long), findsNWidgets(2));
    });

    testWidgets('money_does_not_break_at_the_space_after_the_symbol', (
      tester,
    ) async {
      const money = 'R\$ 2.301.345,45';
      await show(tester, const EllipsisText(money), width: 70);

      expect(tester.getSize(find.text(money)).height, lessThan(30));
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, money);
    });

    testWidgets('more_lines_can_be_allowed_before_the_ellipsis', (
      tester,
    ) async {
      await show(tester, const EllipsisText(long, maxLines: 2));

      final text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, 2);
      expect(text.softWrap, isTrue);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('a_text_with_two_lines_that_fits_has_no_tooltip', (
      tester,
    ) async {
      await show(
        tester,
        const EllipsisText('curto curto curto curto', maxLines: 3),
      );

      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('an_unbounded_width_never_cuts', (tester) async {
      await pumpApp(
        tester,
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [EllipsisText(long)]),
        ),
      );

      expect(find.byType(Tooltip), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
