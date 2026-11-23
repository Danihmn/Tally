import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/card_bill.dart';
import 'package:mobile/features/accounts/domain/usecases/get_card_bill.dart';
import 'package:mobile/features/accounts/presentation/viewmodels/card_bill_view_model.dart';
import 'package:mobile/features/accounts/presentation/views/card_bill_args.dart';
import 'package:mobile/features/accounts/presentation/views/card_bill_view.dart';

import '../../support/fake_transactions_repository.dart';
import '../../support/pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  late FakeAccountsRepository repository;

  setUp(() => repository = FakeAccountsRepository());

  CardBill billWith(List<CardBillItem> items, {bool estimated = false}) =>
      CardBill(
        accountId: 'a2',
        month: DateTime(2026, 12),
        total: Decimal.parse('30.00'),
        estimated: estimated,
        items: items,
      );

  final installment = CardBillItem(
    id: 't1',
    day: DateTime(2026, 11, 20),
    description: 'Loja de Móveis',
    amount: Decimal.parse('30.00'),
    isCredit: false,
    isPending: true,
    installmentNumber: 1,
    totalInstallments: 10,
  );

  Future<void> pumpView(WidgetTester tester, {CardBillArgs? args}) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final card = repository.balances.firstWhere((b) => b.id == 'a2');
    await pumpApp(
      tester,
      CardBillView(
        args: args ?? CardBillArgs(account: card),
        createViewModel: (id) => CardBillViewModel(
          accountId: id,
          getBill: GetCardBill(repository),
          now: () => DateTime(2026, 11, 23),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CardBillView', () {
    testWidgets('opens_at_next_month_with_the_total_and_the_installment', (
      tester,
    ) async {
      repository.billForced = Result.success(billWith([installment]));

      await pumpView(tester);

      expect(find.text('Itaú Card'), findsOneWidget);
      expect(find.text('Dezembro 2026'), findsOneWidget);
      expect(find.text('Total da fatura'), findsOneWidget);
      expect(find.text('R\$ 30,00'), findsNWidgets(2));
      expect(find.text('Loja de Móveis'), findsOneWidget);
      expect(find.text('20/11 · Parcela 1/10 · Em aberto'), findsOneWidget);
      expect(repository.billCalls.single, ('a2', DateTime(2026, 12)));
    });

    testWidgets('the_arrow_loads_the_next_month', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();

      expect(find.text('Janeiro 2027'), findsOneWidget);
      expect(repository.billCalls.last, ('a2', DateTime(2027)));
    });

    testWidgets('an_empty_bill_says_so', (tester) async {
      await pumpView(tester);

      expect(find.text('Nenhuma compra nesta fatura'), findsOneWidget);
      expect(find.text('R\$ 0,00'), findsOneWidget);
    });

    testWidgets('an_estimated_bill_shows_the_note', (tester) async {
      repository.billForced = Result.success(
        billWith([installment], estimated: true),
      );

      await pumpView(tester);

      expect(find.textContaining('Valor estimado'), findsOneWidget);
    });

    testWidgets('a_failure_shows_the_retry', (tester) async {
      repository.billForced = const Result.failure(NetworkFailure());

      await pumpView(tester);

      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });
}
