import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_navigation_bar.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  Future<void> pumpRouter(
    WidgetTester tester, {
    String? Function(BuildContext, Object)? redirect,
  }) {
    final router = createAppRouter(
      chat: const Text('CHAT-PAGE'),
      conversations: const Text('CONVERSATIONS-PAGE'),
      home: const SizedBox(),
      login: const SizedBox(),
      transactions: const SizedBox(),
      entries: const SizedBox(),
      accounts: const Center(child: Text('ACCOUNTS-PAGE')),
      transactionDetail: (args) =>
          Text(args == null ? 'TX-DETAIL-NONE' : 'TX-DETAIL'),
      entryDetail: (args) =>
          Text(args == null ? 'ENTRY-DETAIL-NONE' : 'ENTRY-DETAIL'),
      cardBill: (args) => Text(args == null ? 'CARD-BILL-NONE' : 'CARD-BILL'),
      users: const Text('USERS-PAGE'),
      userDetail: (member) => Text(
        member == null ? 'USER-DETAIL-NONE' : 'USER-${member.firstName}',
      ),
      redirect: redirect == null
          ? null
          : (context, state) => redirect(context, state),
    );
    return tester.pumpWidget(
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
  }

  group('app router', () {
    testWidgets('opens_on_home_with_the_five_tabs_of_the_design', (
      tester,
    ) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      final bar = find.byType(AppNavigationBar);
      for (final label in [
        'Início',
        'Transações',
        'Planejamento',
        'Contas',
        'Tally AI',
      ]) {
        expect(
          find.descendant(of: bar, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(AppRoutes.home, '/home');
    });

    testWidgets(
      'the_conversations_route_opens_over_the_tabs_and_pops_a_value',
      (tester) async {
        await pumpRouter(tester);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(AppNavigationBar));

        final result = GoRouter.of(context)
            .push<String>(AppRoutes.chatConversations);
        await tester.pumpAndSettle();
        expect(find.text('CONVERSATIONS-PAGE'), findsOneWidget);
        expect(find.byType(AppNavigationBar), findsNothing);

        GoRouter.of(tester.element(find.text('CONVERSATIONS-PAGE'))).pop('c1');
        await tester.pumpAndSettle();

        expect(await result, 'c1');
      },
    );

    testWidgets('the_chat_tab_shows_the_chat_view', (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppNavigationBar),
          matching: find.text('Tally AI'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CHAT-PAGE'), findsOneWidget);
    });

    testWidgets('the_transaction_detail_without_args_gets_null', (
      tester,
    ) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      GoRouter.of(tester.element(find.byType(AppNavigationBar)))
          .go(AppRoutes.transactionDetail);
      await tester.pumpAndSettle();

      expect(find.text('TX-DETAIL-NONE'), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsNothing);
    });

    testWidgets('the_entry_detail_without_args_gets_null', (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      GoRouter.of(tester.element(find.byType(AppNavigationBar)))
          .go(AppRoutes.entryDetail);
      await tester.pumpAndSettle();

      expect(find.text('ENTRY-DETAIL-NONE'), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsNothing);
    });

    testWidgets('the_card_bill_without_args_gets_null', (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      GoRouter.of(tester.element(find.byType(AppNavigationBar)))
          .go(AppRoutes.cardBill);
      await tester.pumpAndSettle();

      expect(find.text('CARD-BILL-NONE'), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsNothing);
    });

    testWidgets('the_users_screen_opens_over_the_tabs', (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      GoRouter.of(tester.element(find.byType(AppNavigationBar)))
          .go(AppRoutes.users);
      await tester.pumpAndSettle();

      expect(find.text('USERS-PAGE'), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsNothing);
    });

    testWidgets('the_user_detail_gets_the_person_it_was_opened_with', (
      tester,
    ) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(AppNavigationBar)));

      unawaited(
        router.push(
          AppRoutes.userDetail,
          extra: const Member(id: 'm1', firstName: 'Ana', householdId: 'h'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('USER-Ana'), findsOneWidget);
    });

    testWidgets('the_user_detail_without_a_person_gets_null', (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      GoRouter.of(tester.element(find.byType(AppNavigationBar)))
          .go(AppRoutes.userDetail);
      await tester.pumpAndSettle();

      expect(find.text('USER-DETAIL-NONE'), findsOneWidget);
    });

    testWidgets('tapping_a_tab_shows_its_screen', (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppNavigationBar),
          matching: find.text('Contas'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNTS-PAGE'), findsOneWidget);
    });
  });
}
