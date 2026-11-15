import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/widgets/app_bottom_sheet.dart';

import '../../support/pump_app.dart';

void main() {
  const screenHeight = 800.0;

  Future<void> open(WidgetTester tester, Widget content) async {
    tester.view.physicalSize = const Size(400, screenHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showAppBottomSheet<void>(context, builder: (_) => content),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showAppBottomSheet', () {
    testWidgets('a_tall_sheet_never_takes_more_than_80_percent_of_the_screen', (
      tester,
    ) async {
      await open(
        tester,
        const SingleChildScrollView(child: SizedBox(height: 3000)),
      );

      final height = tester.getSize(find.byType(BottomSheet)).height;
      expect(height, lessThanOrEqualTo(screenHeight * 0.8));
      expect(height, greaterThan(screenHeight * 0.7));
    });

    testWidgets('a_short_sheet_keeps_its_own_height', (tester) async {
      await open(tester, const SizedBox(height: 100, child: Text('short')));

      final height = tester.getSize(find.byType(BottomSheet)).height;
      expect(height, lessThan(screenHeight * 0.4));
      expect(find.text('short'), findsOneWidget);
    });

    testWidgets('the_sheet_closes_with_a_swipe_down', (tester) async {
      await open(tester, const SizedBox(height: 100, child: Text('short')));

      await tester.drag(find.text('short'), const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(find.text('short'), findsNothing);
    });
  });
}
