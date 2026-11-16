import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_args.dart';
import 'package:mobile/features/transactions/presentation/views/transaction_detail_args.dart';
import 'package:mobile/features/transactions/presentation/views/transaction_detail_view.dart';
import 'package:mobile/features/transactions/presentation/widgets/linked_entry_section.dart';

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
    TransactionDetailArgs? args,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      TransactionDetailView(
        args: args,
        createLinkedViewModel: kit.linkedEntries,
      ),
    );
    await tester.pumpAndSettle();
  }

  TransactionDetailArgs argsOf(
    String id, {
    String? description = 'Netflix.com',
  }) => TransactionDetailArgs(
    transaction: makeTransaction(
      id: id,
      description: description,
      amount: '-169.80',
      date: DateTime.utc(2026, 11, 12),
      category: 'Video streaming',
      merchantName: 'Netflix',
      balance: '912.00',
    ),
    account: account,
    owner: ana,
    ownerColorIndex: 0,
  );

  group('TransactionDetailView', () {
    testWidgets('shows_every_known_field_of_the_transaction', (tester) async {
      await pumpDetail(tester, argsOf('t1'));

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
      await pumpDetail(
        tester,
        TransactionDetailArgs(
          transaction: makeTransaction(description: null),
          account: null,
          owner: null,
          ownerColorIndex: 0,
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
      await pumpDetail(tester, null);

      expect(
        find.text('Não foi possível abrir esta transação.'),
        findsOneWidget,
      );
      expect(find.text('Voltar para a lista'), findsOneWidget);
      expect(find.byType(LinkedEntrySection), findsNothing);
    });
  });

  group('TransactionDetailView linked entry', () {
    testWidgets('shows_the_entry_matched_with_the_transaction', (tester) async {
      kit.entries.byTransaction['t1'] = [
        makeEntry(
          id: 'e9',
          description: 'Streaming',
          amount: '169.80',
          status: EntryStatus.reconciled,
        ),
      ];
      await pumpDetail(tester, argsOf('t1'));

      expect(find.text('Lançamento vinculado'), findsOneWidget);
      expect(find.text('Streaming'), findsOneWidget);
      expect(find.text('Venc. 20/11 · Ref. nov'), findsOneWidget);
      expect(find.text('Conciliado'), findsOneWidget);
      expect(kit.entries.calls.single.transactionId, 't1');
    });

    testWidgets('without_an_entry_it_says_so_and_offers_to_link_one', (
      tester,
    ) async {
      await pumpDetail(tester, argsOf('t1'));

      expect(find.text('Sem lançamento'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Vincular'), findsOneWidget);
      expect(find.byTooltip('Desvincular'), findsNothing);
    });

    testWidgets('linking_lists_planned_expenses_and_links_the_one_tapped', (
      tester,
    ) async {
      await pumpDetail(tester, argsOf('t1'));

      await tester.tap(find.widgetWithText(TextButton, 'Vincular'));
      await tester.pumpAndSettle();
      expect(find.text('Vincular lançamento'), findsOneWidget);
      final call = kit.entries.calls.last;
      expect(call.status, EntryStatus.planned);
      // The transaction is a debit, so only expenses are offered.
      expect(call.filters.type, EntryType.expenses);

      await tester.tap(find.text('Internet'));
      await tester.pumpAndSettle();

      expect(kit.transactions.linked.single, ('t1', 'e2'));
      expect(find.text('Lançamento vinculado.'), findsOneWidget);
      expect(find.text('Vincular lançamento'), findsNothing);
    });

    testWidgets('a_failed_link_keeps_the_sheet_open_with_the_reason', (
      tester,
    ) async {
      kit.transactions.linkResult = const Result.failure(
        ServerUnavailableFailure(),
      );
      await pumpDetail(tester, argsOf('t1'));

      await tester.tap(find.widgetWithText(TextButton, 'Vincular'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Internet'));
      await tester.pumpAndSettle();

      expect(find.text('Vincular lançamento'), findsOneWidget);
      expect(
        find.text('Serviço indisponível. Tente novamente em instantes.'),
        findsOneWidget,
      );
    });

    testWidgets('unlinking_asks_first_and_sends_the_pair', (tester) async {
      kit.entries.byTransaction['t1'] = [
        makeEntry(
          id: 'e9',
          description: 'Streaming',
          status: EntryStatus.reconciled,
        ),
      ];
      await pumpDetail(tester, argsOf('t1'));

      await tester.tap(find.byTooltip('Desvincular'));
      await tester.pumpAndSettle();
      expect(find.text('Desvincular o lançamento?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Desvincular'));
      await tester.pumpAndSettle();

      expect(kit.transactions.unlinked.single, ('t1', 'e9'));
      expect(find.text('Lançamento desvinculado.'), findsOneWidget);
    });

    testWidgets('backing_out_of_the_unlink_dialog_sends_nothing', (
      tester,
    ) async {
      kit.entries.byTransaction['t1'] = [
        makeEntry(id: 'e9', status: EntryStatus.reconciled),
      ];
      await pumpDetail(tester, argsOf('t1'));

      await tester.tap(find.byTooltip('Desvincular'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(kit.transactions.unlinked, isEmpty);
    });

    testWidgets('a_failure_only_breaks_the_block_and_retry_works', (
      tester,
    ) async {
      kit.entries.forced = const Result.failure(NetworkFailure());
      await pumpDetail(tester, argsOf('t1'));
      expect(find.text('Não foi possível carregar o vínculo.'), findsOneWidget);
      expect(find.text('Netflix.com'), findsWidgets);

      kit.entries.forced = null;
      kit.entries.byTransaction['t1'] = [
        makeEntry(description: 'Streaming', status: EntryStatus.reconciled),
      ];
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Streaming'), findsOneWidget);
    });

    testWidgets('tapping_the_entry_opens_it_with_account_and_owner', (
      tester,
    ) async {
      kit.entries.byTransaction['t1'] = [
        makeEntry(
          id: 'e9',
          description: 'Streaming',
          accountId: 'a2',
          ownerId: 'm2',
          status: EntryStatus.reconciled,
        ),
      ];
      EntryDetailArgs? opened;
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        LinkedEntrySection(
          transactionId: 't1',
          isIncome: false,
          createViewModel: kit.linkedEntries,
          onOpenEntry: (args) => opened = args,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Streaming'));

      expect(opened?.entry.id, 'e9');
      expect(opened?.account?.marketingName, 'Itaú Card');
      expect(opened?.owner?.firstName, 'Bia');
      expect(opened?.ownerColorIndex, 1);
    });
  });
}
