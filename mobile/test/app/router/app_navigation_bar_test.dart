import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_navigation_bar.dart';

import '../../support/pump_app.dart';

void main() {
  const items = [
    AppNavigationItem(icon: Icons.home_outlined, label: 'Início'),
    AppNavigationItem(icon: Icons.event_note_outlined, label: 'Planejamento'),
    AppNavigationItem(icon: Icons.auto_awesome_outlined, label: 'Tally AI'),
  ];

  Future<void> show(
    WidgetTester tester, {
    double width = 360,
    int selected = 0,
    ValueChanged<int>? onSelected,
    List<AppNavigationItem> tabs = items,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: AppNavigationBar(
          items: tabs,
          selectedIndex: selected,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    );
  }

  group('AppNavigationBar', () {
    testWidgets('shows_every_label_once', (tester) async {
      await show(tester, width: 800);

      for (final item in items) {
        expect(find.text(item.label), findsOneWidget);
      }
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('tapping_a_tab_reports_its_index', (tester) async {
      final taps = <int>[];
      await show(tester, width: 800, onSelected: taps.add);

      await tester.tap(find.text('Planejamento'));
      await tester.tap(find.text('Início'));

      expect(taps, [1, 0]);
    });

    testWidgets('the_open_tab_is_marked_as_selected', (tester) async {
      await show(tester, width: 800, selected: 1);

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Planejamento')),
        matchesSemantics(
          label: 'Planejamento',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a_long_label_stays_on_one_line_with_an_ellipsis', (
      tester,
    ) async {
      const long = AppNavigationItem(
        icon: Icons.home_outlined,
        label: 'Planejamento financeiro',
      );
      await show(tester, tabs: const [long, long]);

      final text = tester.widget<Text>(find.text(long.label).first);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a_cut_label_shows_its_whole_name_on_a_long_press', (
      tester,
    ) async {
      const long = AppNavigationItem(
        icon: Icons.home_outlined,
        label: 'Planejamento financeiro',
      );
      await show(tester, tabs: const [long, long, long, long, long]);

      await tester.longPress(find.text(long.label).first);
      await tester.pumpAndSettle();

      expect(find.text(long.label), findsNWidgets(6));
    });
  });
}
