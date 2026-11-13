import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/transactions/presentation/views/transaction_detail_args.dart';
import 'package:mobile/features/transactions/presentation/views/transaction_detail_view.dart';

import '../../../support/pump_app.dart';
import '../../../support/transaction_factory.dart';
import '../../../support/transactions_kit.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  const account = BankAccount(
    id: 'a1',
    ownerId: 'm1',
    name: 'Conta Corrente',
    marketingName: 'Nubank',
    number: '0001/123456',
    isCreditCard: false,
  );

  group('TransactionDetailView', () {
    testWidgets('shows_every_known_field_of_the_transaction', (tester) async {
      await pumpApp(
        tester,
        TransactionDetailView(
          args: TransactionDetailArgs(
            transaction: makeTransaction(
              description: 'Netflix.com',
              amount: '-169.80',
              date: DateTime.utc(2026, 11, 12),
              category: 'Video streaming',
              merchantName: 'Netflix',
              balance: '912.00',
            ),
            account: account,
            owner: ana,
            ownerColorIndex: 0,
          ),
        ),
      );

      expect(find.text('12/11/2026'), findsOneWidget);
      expect(find.text('Video streaming'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Nubank ••3456'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Débito'), findsOneWidget);
      expect(find.text('Efetivada'), findsWidgets);
      expect(find.text('Saldo após'), findsOneWidget);
    });

    testWidgets('leaves_out_what_the_transaction_does_not_have', (
      tester,
    ) async {
      await pumpApp(
        tester,
        TransactionDetailView(
          args: TransactionDetailArgs(
            transaction: makeTransaction(description: null),
            account: null,
            owner: null,
            ownerColorIndex: 0,
          ),
        ),
      );

      expect(find.text('Categoria'), findsNothing);
      expect(find.text('Estabelecimento'), findsNothing);
      expect(find.text('Conta'), findsNothing);
      expect(find.text('Titular'), findsNothing);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('without_args_it_says_so_and_offers_to_go_back', (
      tester,
    ) async {
      await pumpApp(tester, const TransactionDetailView(args: null));

      expect(
        find.text('Não foi possível abrir esta transação.'),
        findsOneWidget,
      );
      expect(find.text('Voltar para a lista'), findsOneWidget);
    });
  });
}
