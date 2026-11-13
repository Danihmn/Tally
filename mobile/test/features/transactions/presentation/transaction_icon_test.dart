import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/presentation/widgets/transaction_icon.dart';

import '../../../support/pump_app.dart';
import '../../../support/transaction_factory.dart';

void main() {
  Future<IconData?> iconOf(WidgetTester tester, Transaction t) async {
    await pumpApp(tester, TransactionIcon(transaction: t));
    return tester.widget<Icon>(find.byType(Icon)).icon;
  }

  group('TransactionIcon', () {
    testWidgets('a_known_category_group_picks_its_icon', (tester) async {
      expect(
        await iconOf(tester, makeTransaction(categoryId: '19040000')),
        Icons.directions_car_outlined,
      );
    });

    testWidgets('an_unknown_group_follows_the_direction', (tester) async {
      expect(
        await iconOf(tester, makeTransaction(categoryId: '99000000')),
        Icons.north_east_rounded,
      );
      expect(
        await iconOf(
          tester,
          makeTransaction(
            categoryId: '99000000',
            direction: TransactionDirection.credit,
          ),
        ),
        Icons.south_west_rounded,
      );
    });

    testWidgets('a_missing_or_short_category_id_does_not_break', (
      tester,
    ) async {
      expect(await iconOf(tester, makeTransaction()), Icons.north_east_rounded);
      expect(
        await iconOf(tester, makeTransaction(categoryId: '1')),
        Icons.north_east_rounded,
      );
    });
  });
}
