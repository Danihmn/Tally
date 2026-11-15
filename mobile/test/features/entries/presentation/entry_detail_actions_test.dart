import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_args.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_view.dart';

import '../../../support/entries_kit.dart';
import '../../../support/entry_factory.dart';
import '../../../support/pump_app.dart';
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

  /// Opens the detail over a first screen, like the router does, and keeps
  /// what the detail answered when it closed.
  Future<void> openDetail(
    WidgetTester tester,
    FinancialEntry entry,
    List<bool?> answers,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final answer = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => EntryDetailView(
                  args: EntryDetailArgs(
                    entry: entry,
                    account: account,
                    owner: ana,
                    ownerColorIndex: 0,
                    accounts: const [account],
                  ),
                  createLinkedViewModel: kit.linkedTransactions,
                  createActionsViewModel: kit.actions,
                  now: () => DateTime(2026, 11, 13),
                ),
              ),
            );
            answers.add(answer);
          },
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  group('EntryDetailActions buttons', () {
    testWidgets('a_planned_entry_offers_edit_cancel_and_delete', (
      tester,
    ) async {
      await openDetail(tester, makeEntry(), []);

      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Cancelar lançamento'), findsOneWidget);
      expect(find.text('Excluir lançamento'), findsOneWidget);
      expect(find.text('Reativar lançamento'), findsNothing);
    });

    testWidgets('a_cancelled_entry_offers_reopen_instead_of_cancel', (
      tester,
    ) async {
      await openDetail(tester, makeEntry(status: EntryStatus.cancelled), []);

      expect(find.text('Reativar lançamento'), findsOneWidget);
      expect(find.text('Cancelar lançamento'), findsNothing);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Excluir lançamento'), findsOneWidget);
    });

    testWidgets('a_reconciled_entry_has_no_buttons_only_a_note', (
      tester,
    ) async {
      await openDetail(tester, makeEntry(status: EntryStatus.reconciled), []);

      expect(find.text('Editar'), findsNothing);
      expect(find.text('Cancelar lançamento'), findsNothing);
      expect(find.text('Excluir lançamento'), findsNothing);
      expect(
        find.textContaining('Desfaça a conciliação antes'),
        findsOneWidget,
      );
    });
  });

  group('EntryDetailActions changes', () {
    testWidgets('cancelling_changes_the_status_and_closes_answering_true', (
      tester,
    ) async {
      final answers = <bool?>[];
      await openDetail(tester, makeEntry(), answers);

      await tester.tap(find.text('Cancelar lançamento'));
      await tester.pumpAndSettle();

      expect(kit.entries.statusChanges, [('e1', EntryStatus.cancelled)]);
      expect(answers, [true]);
      expect(find.text('Lançamento cancelado.'), findsOneWidget);
    });

    testWidgets('reopening_sets_the_entry_back_to_planned', (tester) async {
      final answers = <bool?>[];
      await openDetail(
        tester,
        makeEntry(status: EntryStatus.cancelled),
        answers,
      );

      await tester.tap(find.text('Reativar lançamento'));
      await tester.pumpAndSettle();

      expect(kit.entries.statusChanges, [('e1', EntryStatus.planned)]);
      expect(answers, [true]);
    });

    testWidgets(
      'deleting_asks_first_and_does_nothing_if_the_person_backs_out',
      (tester) async {
        final answers = <bool?>[];
        await openDetail(tester, makeEntry(), answers);

        await tester.tap(find.text('Excluir lançamento'));
        await tester.pumpAndSettle();
        expect(find.text('Excluir lançamento?'), findsOneWidget);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(kit.entries.deleted, isEmpty);
        expect(answers, isEmpty);
        expect(find.text('Editar'), findsOneWidget);
      },
    );

    testWidgets('confirming_the_delete_removes_the_entry_and_closes', (
      tester,
    ) async {
      final answers = <bool?>[];
      await openDetail(tester, makeEntry(), answers);

      await tester.tap(find.text('Excluir lançamento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(kit.entries.deleted, ['e1']);
      expect(answers, [true]);
      expect(find.text('Lançamento excluído.'), findsOneWidget);
    });

    testWidgets('editing_sends_the_whole_form_and_closes', (tester) async {
      final answers = <bool?>[];
      await openDetail(tester, makeEntry(), answers);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar lançamento'), findsOneWidget);
      // The form starts with what the entry has.
      expect(find.text('Aluguel'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'Aluguel novo');
      await tester.tap(find.text('Salvar lançamento'));
      await tester.pumpAndSettle();

      final (id, draft) = kit.entries.updated.single;
      expect(id, 'e1');
      expect(draft.description, 'Aluguel novo');
      expect(draft.amount.toString(), '1500');
      expect(draft.referenceMonth, DateTime(2026, 11));
      expect(draft.dueDate, DateTime(2026, 11, 20));
      expect(draft.accountId, 'a1');
      expect(answers, [true]);
    });

    testWidgets('a_failure_keeps_the_screen_and_says_why', (tester) async {
      final answers = <bool?>[];
      kit.entries.writeFailure = const NetworkFailure();
      await openDetail(tester, makeEntry(), answers);

      await tester.tap(find.text('Cancelar lançamento'));
      await tester.pumpAndSettle();

      expect(answers, isEmpty);
      expect(
        find.text('Sem conexão. Verifique sua internet e tente de novo.'),
        findsOneWidget,
      );
      expect(find.text('Cancelar lançamento'), findsOneWidget);
    });
  });
}
