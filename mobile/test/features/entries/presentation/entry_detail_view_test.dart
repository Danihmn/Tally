import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_args.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_view.dart';

import '../../../support/entries_kit.dart';
import '../../../support/entry_factory.dart';
import '../../../support/pump_app.dart';
import '../../../support/transaction_factory.dart';
import '../../../support/transactions_kit.dart';

void main() {
  late EntriesKit kit;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() async {
    kit = EntriesKit();
    await kit.scope.ensureLoaded();
  });

  tearDown(() => kit.dispose());

  const account = BankAccount(
    id: 'a1',
    ownerId: 'm1',
    name: 'Conta Corrente',
    marketingName: 'Nubank',
    number: '0001/123456',
    isCreditCard: false,
  );

  Future<void> pumpDetail(
    WidgetTester tester,
    FinancialEntry entry, {
    BankAccount? entryAccount = account,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      EntryDetailView(
        args: EntryDetailArgs(
          entry: entry,
          account: entryAccount,
          owner: ana,
          ownerColorIndex: 0,
        ),
        createLinkedViewModel: kit.linkedTransactions,
        now: () => DateTime(2026, 11, 13),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('EntryDetailView', () {
    testWidgets('shows_every_known_field_of_the_entry', (tester) async {
      await pumpDetail(
        tester,
        makeEntry(
          installmentNumber: 2,
          installmentTotal: 5,
          notes: 'Contrato anual',
        ),
      );

      expect(find.text('Aluguel'), findsWidgets);
      expect(find.text('Despesa'), findsOneWidget);
      expect(find.text('Débito'), findsOneWidget);
      expect(find.text('Moradia'), findsOneWidget);
      expect(find.textContaining('1.500,00'), findsWidgets);
      expect(find.text('novembro de 2026'), findsOneWidget);
      expect(find.text('20/11/2026'), findsOneWidget);
      expect(find.text('Nubank ••3456'), findsOneWidget);
      expect(find.text('2 de 5'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Contrato anual'), findsOneWidget);
    });

    testWidgets('leaves_out_what_the_entry_does_not_have', (tester) async {
      await pumpDetail(
        tester,
        makeEntry(category: null, paymentType: null, accountId: null),
        entryAccount: null,
      );

      expect(find.text('Categoria'), findsNothing);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('a_planned_entry_waits_and_does_not_look_for_a_transaction', (
      tester,
    ) async {
      await pumpDetail(tester, makeEntry());

      expect(find.text('Aguardando conciliação'), findsOneWidget);
      expect(find.text('Transação do banco'), findsNothing);
      expect(kit.transactions.calls, isEmpty);
    });

    testWidgets('an_overdue_entry_says_overdue', (tester) async {
      await pumpDetail(tester, makeEntry(dueDate: DateTime(2026, 11, 10)));

      expect(find.text('Vencido'), findsOneWidget);
      expect(find.text('Vence em 10/11/2026'), findsOneWidget);
    });

    testWidgets('a_cancelled_entry_says_it_will_not_be_charged', (
      tester,
    ) async {
      await pumpDetail(tester, makeEntry(status: EntryStatus.cancelled));

      expect(find.text('Cancelado'), findsWidgets);
      expect(find.text('Não será cobrado nem conciliado.'), findsOneWidget);
    });

    testWidgets('the_timeline_says_who_created_it', (tester) async {
      await pumpDetail(tester, makeEntry());

      expect(find.text('01/11/2026 · por Ana'), findsOneWidget);
    });

    testWidgets('has_no_buttons_to_change_the_entry', (tester) async {
      await pumpDetail(tester, makeEntry());

      expect(find.text('Conciliar com uma transação'), findsNothing);
      expect(find.text('Cancelar lançamento'), findsNothing);
      expect(find.text('Desfazer conciliação'), findsNothing);
      expect(find.text('Reativar lançamento'), findsNothing);
    });

    testWidgets('without_args_it_says_so_and_offers_to_go_back', (
      tester,
    ) async {
      await pumpApp(
        tester,
        EntryDetailView(
          args: null,
          createLinkedViewModel: kit.linkedTransactions,
        ),
      );

      expect(
        find.text('Não foi possível abrir este lançamento.'),
        findsOneWidget,
      );
      expect(find.text('Voltar para a lista'), findsOneWidget);
    });
  });

  group('EntryDetailView linked transaction', () {
    testWidgets('a_reconciled_entry_shows_its_bank_transaction', (
      tester,
    ) async {
      kit.transactions.all = [
        makeTransaction(
          id: 't7',
          description: 'ENEL SP',
          amount: '180.00',
          date: DateTime.utc(2026, 11, 8),
        ),
      ];
      await pumpDetail(
        tester,
        makeEntry(id: 'e4', status: EntryStatus.reconciled),
      );

      expect(find.text('Transação do banco'), findsOneWidget);
      expect(find.text('ENEL SP'), findsOneWidget);
      expect(find.text('08/11/2026 · Nubank'), findsOneWidget);
      expect(kit.transactions.calls.single.financialEntryId, 'e4');
    });

    testWidgets('a_failure_only_breaks_the_block_and_retry_works', (
      tester,
    ) async {
      kit.transactions.forced = const Result.failure(NetworkFailure());
      await pumpDetail(
        tester,
        makeEntry(id: 'e4', status: EntryStatus.reconciled),
      );
      expect(find.text('Não foi possível carregar o vínculo.'), findsOneWidget);
      expect(find.text('Aluguel'), findsWidgets);

      kit.transactions.forced = null;
      kit.transactions.all = [makeTransaction(description: 'ENEL SP')];
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('ENEL SP'), findsOneWidget);
    });

    testWidgets('nothing_matched_says_so', (tester) async {
      kit.transactions.all = [];
      await pumpDetail(
        tester,
        makeEntry(id: 'e4', status: EntryStatus.reconciled),
      );

      expect(
        find.text('Nenhuma transação ligada a este lançamento ainda.'),
        findsOneWidget,
      );
    });
  });
}
