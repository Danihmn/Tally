import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/features/transactions/presentation/widgets/transaction_row.dart';

import '../../../support/pump_app.dart';
import '../../../support/transaction_factory.dart';

void main() {
  const longDescription =
      'Compra no débito em um estabelecimento com um nome gigantesco '
      'que não cabe em uma linha de jeito nenhum';

  Future<void> show(
    WidgetTester tester,
    TransactionRow row, {
    double width = 360,
  }) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return pumpApp(tester, row);
  }

  TransactionRow row({
    String? description = 'Mercado',
    String amount = '-100.00',
    VoidCallback? onTap,
  }) => TransactionRow(
    transaction: makeTransaction(description: description, amount: amount),
    accountName: 'Conta Corrente',
    ownerInitial: 'A',
    ownerColor: Colors.blue,
    onTap: onTap ?? () {},
  );

  group('TransactionRow', () {
    testWidgets('a_long_description_gets_an_ellipsis_and_does_not_overflow', (
      tester,
    ) async {
      await show(tester, row(description: longDescription));

      final text = tester.widget<Text>(find.text(longDescription));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a_long_press_on_the_description_shows_the_whole_value', (
      tester,
    ) async {
      await show(tester, row(description: longDescription));

      await tester.longPress(find.text(longDescription));
      await tester.pumpAndSettle();

      expect(find.text(longDescription), findsNWidgets(2));
    });

    testWidgets('a_tap_still_opens_the_row_and_no_tooltip_appears', (
      tester,
    ) async {
      var taps = 0;
      await show(
        tester,
        row(description: longDescription, onTap: () => taps++),
      );

      await tester.tap(find.text(longDescription));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.text(longDescription), findsOneWidget);
    });

    testWidgets('a_short_description_has_no_tooltip', (tester) async {
      await show(tester, row(), width: 800);

      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('a_big_amount_stays_on_one_line', (tester) async {
      await show(tester, row(amount: '-1234567.89'), width: 800);

      final amount = find.textContaining('1.234.567,89');
      expect(amount, findsOneWidget);
      expect(tester.getSize(amount).height, lessThan(24));
      expect(tester.takeException(), isNull);
    });
  });
}
