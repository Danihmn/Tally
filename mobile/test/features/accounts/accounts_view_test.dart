import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/presentation/views/accounts_view.dart';
import 'package:mobile/features/accounts/presentation/widgets/account_card.dart';
import 'package:mobile/features/transactions/domain/transactions_filter_request.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../support/accounts_kit.dart';
import '../../support/pump_app.dart';

void main() {
  late AccountsKit kit;
  late TransactionsFilterRequest request;

  setUp(() {
    kit = AccountsKit();
    request = TransactionsFilterRequest();
  });
  tearDown(() {
    request.dispose();
    kit.session.dispose();
  });

  Future<void> pumpView(
    WidgetTester tester, {
    VoidCallback? onOpenTransactions,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      AccountsView(
        createViewModel: () => kit.viewModel,
        filterRequest: request,
        onOpenTransactions: onOpenTransactions ?? () {},
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AccountsView header', () {
    testWidgets('shows_the_total_of_the_accounts_and_the_open_bills', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Saldo total em contas'), findsOneWidget);
      expect(find.text('R\$ 2.301,45'), findsWidgets);
      expect(
        find.text('Faturas abertas nos cartões: R\$ 1.500,00'),
        findsOneWidget,
      );
    });

    testWidgets('without_cards_it_says_so', (tester) async {
      kit.accounts.balances = [
        for (final b in kit.accounts.balances)
          if (!b.isCreditCard) b,
      ];
      await pumpView(tester);

      expect(find.text('Sem cartões conectados'), findsOneWidget);
    });

    testWidgets('failed_totals_show_a_message_and_retry_loads_them', (
      tester,
    ) async {
      kit.accounts.totalForced = const Result.failure(NetworkFailure());
      await pumpView(tester);
      expect(find.text('Não foi possível carregar os totais.'), findsOneWidget);
      // The list still shows.
      expect(find.text('Nubank'), findsOneWidget);

      kit.accounts.totalForced = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar os totais.'), findsNothing);
    });
  });

  group('AccountsView list', () {
    testWidgets('the_tabs_show_how_many_accounts_and_cards_there_are', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Contas bancárias 1'), findsOneWidget);
      expect(find.text('Cartões de crédito 1'), findsOneWidget);
    });

    testWidgets('an_account_shows_its_name_number_owner_and_balance', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Nubank'), findsOneWidget);
      expect(find.text('Conta •••• 3456'), findsOneWidget);
      expect(find.text('Saldo atual'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Ver transações'), findsOneWidget);
    });

    testWidgets('the_cards_tab_shows_the_bill_and_the_limit_bar', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(find.text('Cartões de crédito 1'));
      await tester.pumpAndSettle();

      expect(find.text('Itaú Card'), findsOneWidget);
      expect(find.text('Cartão •••• 1234'), findsOneWidget);
      expect(find.text('Fatura atual'), findsOneWidget);
      expect(
        find.text('Usado 30% · Limite R\$ 5.000,00 · Disponível R\$ 3.500,00'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('a_card_without_credit_data_has_no_bar', (tester) async {
      await pumpView(tester);
      await tester.tap(find.text('Casa'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Cartões de crédito'));
      await tester.pumpAndSettle();

      expect(find.text('Cartão Nu'), findsNothing); // shows marketing name
      expect(find.text('Cartão •••• 9876'), findsOneWidget);
      // Only the Itaú card has a bar.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('the_house_shows_the_accounts_of_everyone', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('Casa'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountCard), findsNWidgets(2));
      expect(find.text('Inter'), findsOneWidget);
    });

    testWidgets('nothing_connected_says_the_person_has_no_bank', (
      tester,
    ) async {
      kit.accounts.balances = [];
      await pumpView(tester);

      expect(find.text('Ana ainda não conectou nenhum banco'), findsOneWidget);
      expect(
        find.text(
          'Conecte um banco pelo Meu Pluggy para ver contas e cartões aqui.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a_tab_without_items_says_so', (tester) async {
      kit.accounts.balances = [
        for (final b in kit.accounts.balances)
          if (!b.isCreditCard) b,
      ];
      await pumpView(tester);

      await tester.tap(find.textContaining('Cartões de crédito'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum cartão de crédito'), findsOneWidget);
    });

    testWidgets('a_failed_list_shows_the_error_and_retry_loads_it', (
      tester,
    ) async {
      kit.accounts.balancesForced = const Result.failure(NetworkFailure());
      await pumpView(tester);
      expect(find.text('Tentar novamente'), findsOneWidget);

      kit.accounts.balancesForced = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Nubank'), findsOneWidget);
    });

    testWidgets('has_no_connections_section_or_connect_button', (tester) async {
      await pumpView(tester);

      expect(find.text('Conexões bancárias'), findsNothing);
      expect(find.text('Conectar banco'), findsNothing);
    });
  });

  group('AccountsView opens the transactions', () {
    testWidgets('tapping_an_account_asks_for_its_transactions', (tester) async {
      var opened = 0;
      await pumpView(tester, onOpenTransactions: () => opened++);

      await tester.tap(find.byType(AccountCard).first);

      expect(request.pendingAccountId, 'a1');
      expect(opened, 1);
    });

    testWidgets('tapping_a_card_asks_for_its_transactions', (tester) async {
      await pumpView(tester);
      await tester.tap(find.text('Cartões de crédito 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AccountCard).first);

      expect(request.pendingAccountId, 'a2');
    });
    testWidgets('with_the_router_the_tap_goes_to_the_transactions_tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = createAppRouter(
        chat: const SizedBox(),
        conversations: const SizedBox(),
        home: const SizedBox(),
        login: const SizedBox(),
        transactions: const Text('TRANSACTIONS-PAGE'),
        entries: const SizedBox(),
        accounts: AccountsView(
          createViewModel: () => kit.viewModel,
          filterRequest: request,
        ),
        transactionDetail: (_) => const SizedBox(),
        entryDetail: (_) => const SizedBox(),
        initialLocation: AppRoutes.accounts,
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(useGoogleFonts: false),
          locale: const Locale('pt', 'BR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AccountCard).first);
      await tester.pumpAndSettle();

      expect(find.text('TRANSACTIONS-PAGE'), findsOneWidget);
      expect(request.pendingAccountId, 'a1');
    });
  });

  group('AccountsView salary account', () {
    Finder salarySwitch() => find.byType(Switch);

    /// Taps the switch and confirms the change.
    Future<void> toggleAndConfirm(WidgetTester tester) async {
      await tester.tap(salarySwitch());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
    }

    testWidgets('only_bank_accounts_have_the_switch', (tester) async {
      await pumpView(tester);

      expect(find.text('Conta salário'), findsOneWidget);
      expect(salarySwitch(), findsOneWidget);

      await tester.tap(find.text('Cartões de crédito 1'));
      await tester.pumpAndSettle();

      expect(salarySwitch(), findsNothing);
    });

    testWidgets('turning_it_on_saves_at_once_with_the_code_from_the_server', (
      tester,
    ) async {
      await pumpView(tester);

      await toggleAndConfirm(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(kit.accounts.updateCalls, [('a1', true, null)]);
      expect(tester.widget<Switch>(salarySwitch()).value, isTrue);
      expect(find.textContaining('Banco 001'), findsOneWidget);
      // The switch does not open the transactions
      expect(request.pendingAccountId, isNull);
    });

    testWidgets('without_a_code_on_the_server_it_asks_for_one', (tester) async {
      kit.accounts.transferBankCode = null;
      await pumpView(tester);

      await toggleAndConfirm(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Código do banco'), findsWidgets);
      final save = find.widgetWithText(FilledButton, 'Salvar');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '1a');
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '001');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(kit.accounts.updateCalls, [
        ('a1', true, null),
        ('a1', true, '001'),
      ]);
      expect(tester.widget<Switch>(salarySwitch()).value, isTrue);
      expect(find.textContaining('Banco 001'), findsOneWidget);
    });

    testWidgets('the_switch_asks_for_confirmation_before_saving', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(salarySwitch());
      await tester.pumpAndSettle();

      expect(find.text('Marcar como conta salário?'), findsOneWidget);
      expect(find.textContaining('passam a contar como recebido'), findsOne);
      expect(kit.accounts.updateCalls, isEmpty);
    });

    testWidgets('cancelling_the_confirmation_saves_nothing', (tester) async {
      await pumpView(tester);

      await tester.tap(salarySwitch());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(kit.accounts.updateCalls, isEmpty);
      expect(tester.widget<Switch>(salarySwitch()).value, isFalse);
    });

    testWidgets('turning_it_off_also_asks_for_confirmation', (tester) async {
      await pumpView(tester);
      await toggleAndConfirm(tester);

      await tester.tap(salarySwitch());
      await tester.pumpAndSettle();

      expect(find.text('Desmarcar conta salário?'), findsOneWidget);
      expect(
        find.textContaining('voltam a ser transferências internas'),
        findsOne,
      );
      expect(kit.accounts.updateCalls, [('a1', true, null)]);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();

      expect(kit.accounts.updateCalls.last, ('a1', false, null));
      expect(tester.widget<Switch>(salarySwitch()).value, isFalse);
    });

    testWidgets('cancelling_the_dialog_keeps_it_off', (tester) async {
      kit.accounts.transferBankCode = null;
      await pumpView(tester);

      await toggleAndConfirm(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(kit.accounts.updateCalls, [('a1', true, null)]);
      expect(tester.widget<Switch>(salarySwitch()).value, isFalse);
    });

    testWidgets('the_code_of_a_salary_account_can_be_changed', (tester) async {
      await pumpView(tester);
      await toggleAndConfirm(tester);

      await tester.tap(find.byTooltip('Alterar código do banco'));
      await tester.pumpAndSettle();
      // The pencil goes straight to the code: no confirmation
      expect(find.text('Marcar como conta salário?'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '001',
      );
      await tester.enterText(find.byType(TextField), '237');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(kit.accounts.updateCalls.last, ('a1', true, '237'));
      expect(find.textContaining('Banco 237'), findsOneWidget);
    });

    testWidgets('only_a_salary_account_shows_the_edit_button', (tester) async {
      await pumpView(tester);

      expect(find.byTooltip('Alterar código do banco'), findsNothing);
    });

    testWidgets('a_failure_shows_a_message', (tester) async {
      kit.accounts.updateForced = const Result.failure(NetworkFailure());
      await pumpView(tester);

      await toggleAndConfirm(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.widget<Switch>(salarySwitch()).value, isFalse);
    });
  });
}
