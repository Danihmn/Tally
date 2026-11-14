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
}
