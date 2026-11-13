import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/home/domain/entities/daily_amount.dart';
import 'package:mobile/features/home/domain/entities/reconciliation_counts.dart';
import 'package:mobile/features/home/presentation/views/home_view.dart';

import '../../../support/fake_home_repository.dart';
import '../../../support/home_kit.dart';
import '../../../support/pump_app.dart';

void main() {
  late HomeKit kit;

  /// A tall screen: the home is a list and only builds what is on screen.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    VoidCallback? onOpenChat,
    VoidCallback? onOpenEntries,
  }) async {
    useTallScreen(tester);
    await pumpApp(
      tester,
      HomeView(
        createViewModel: () => kit.viewModel,
        onOpenChat: onOpenChat,
        onOpenEntries: onOpenEntries,
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => kit = HomeKit());
  tearDown(() => kit.session.dispose());

  group('HomeView loading', () {
    testWidgets('shows_skeletons_before_the_profile_arrives', (tester) async {
      useTallScreen(tester);
      await pumpApp(tester, HomeView(createViewModel: () => kit.viewModel));

      expect(find.byType(Skeleton), findsWidgets);
      expect(find.text('Olá, Ana'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Olá, Ana'), findsOneWidget);
    });

    testWidgets('a_failed_profile_shows_the_error_and_retry_works', (
      tester,
    ) async {
      kit.household.me = const Result.failure(NetworkFailure());
      await pumpHome(tester);
      expect(
        find.text('Sem conexão. Verifique sua internet e tente de novo.'),
        findsOneWidget,
      );

      kit.household.me = const Result.success(ana);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Olá, Ana'), findsOneWidget);
    });
  });

  group('HomeView content', () {
    testWidgets('shows_the_greeting_and_the_month', (tester) async {
      await pumpHome(tester);

      expect(find.text('Olá, Ana'), findsOneWidget);
      expect(find.text('Novembro 2026'), findsOneWidget);
    });

    testWidgets('shows_the_spent_amount_and_the_average_until_yesterday', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Gasto em novembro'), findsOneWidget);
      expect(find.text('R\$ 1.200,50'), findsOneWidget);
      expect(
        find.text('Média de R\$ 100,00 por dia · até 12/11'),
        findsOneWidget,
      );
    });

    testWidgets('shows_what_was_received_and_the_balance_with_its_sign', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Recebido'), findsOneWidget);
      expect(find.text('R\$ 5.000,00'), findsOneWidget);
      expect(find.text('Saldo do mês'), findsOneWidget);
      expect(find.text('+ R\$ 3.799,50'), findsOneWidget);
    });

    testWidgets('a_negative_balance_shows_the_minus_sign', (tester) async {
      kit.home.balanceResult = Result.success(dec('-35.00'));
      await pumpHome(tester);

      expect(find.text('− R\$ 35,00'), findsOneWidget);
    });

    testWidgets('shows_planned_against_real_with_the_counts', (tester) async {
      await pumpHome(tester);

      expect(find.text('Planejado × real'), findsOneWidget);
      expect(find.text('nov/26'), findsOneWidget);
      expect(find.text('R\$ 3.000,00'), findsOneWidget);
      expect(find.text('R\$ 1.800,00'), findsOneWidget);
      expect(find.text('3 de 5 lançamentos conciliados'), findsOneWidget);
    });

    testWidgets('shows_how_many_entries_need_attention', (tester) async {
      await pumpHome(tester);

      expect(find.text('Precisa de atenção'), findsOneWidget);
      expect(find.text('2 lançamentos sem conciliar'), findsOneWidget);
    });

    testWidgets('without_unreconciled_entries_there_is_no_attention_card', (
      tester,
    ) async {
      const allDone = ReconciliationCounts(reconciled: 2, notReconciled: 0);
      kit.home.expenseCountsResult = const Result.success(allDone);
      kit.home.revenueCountsResult = const Result.success(allDone);
      await pumpHome(tester);

      expect(find.text('Precisa de atenção'), findsNothing);
    });

    testWidgets('shows_the_daily_card_and_the_biggest_expenses', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Gasto por dia'), findsOneWidget);
      expect(find.text('Média R\$ 100,00'), findsOneWidget);
      expect(find.text('Onde mais gastamos'), findsOneWidget);
      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('R\$ 800,00'), findsOneWidget);
      expect(find.text('Sem descrição'), findsOneWidget);
    });

    testWidgets('shows_the_upcoming_entries_with_category_and_when', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Próximos lançamentos'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('15/11 · Moradia'), findsOneWidget);
      expect(find.text('em 2 dias'), findsOneWidget);
      expect(find.text('− R\$ 120,00'), findsOneWidget);
      // A revenue without category shows only the day.
      expect(find.text('+ R\$ 5.000,00'), findsOneWidget);
      expect(find.text('20/11'), findsOneWidget);
    });

    testWidgets('no_upcoming_entries_says_so', (tester) async {
      kit.home.upcomingResult = Result.success([]);
      await pumpHome(tester);

      expect(
        find.text('Nenhum lançamento a vencer nos próximos dias.'),
        findsOneWidget,
      );
    });

    testWidgets('without_spending_it_shows_the_empty_card', (tester) async {
      kit.home.totalExpensesResult = Result.success(dec('0.00'));
      await pumpHome(tester);

      expect(find.text('Ainda não há gastos neste mês'), findsOneWidget);
      expect(find.text('Gasto por dia'), findsNothing);
      expect(find.text('Onde mais gastamos'), findsNothing);
      // The planning and the upcoming entries are still there.
      expect(find.text('Planejado × real'), findsOneWidget);
      expect(find.text('Próximos lançamentos'), findsOneWidget);
    });
  });

  group('HomeView sections fail on their own', () {
    testWidgets('one_failing_card_shows_an_error_and_the_rest_stays', (
      tester,
    ) async {
      kit.home.dailyResult = const Result.failure(ServerUnavailableFailure());
      await pumpHome(tester);

      expect(
        find.text('Serviço indisponível. Tente novamente em instantes.'),
        findsOneWidget,
      );
      expect(find.text('R\$ 1.200,50'), findsOneWidget);
      expect(find.text('Onde mais gastamos'), findsOneWidget);
    });

    testWidgets('retry_loads_only_the_failed_card', (tester) async {
      kit.home.dailyResult = const Result.failure(ServerUnavailableFailure());
      await pumpHome(tester);
      kit.home.dailyResult = Result.success([
        DailyAmount(day: DateTime(2026, 11), amount: dec('10.00')),
      ]);
      kit.home.calls.clear();

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Gasto por dia'), findsOneWidget);
      expect(kit.home.calls, hasLength(1));
    });

    testWidgets('a_section_without_connection_shows_the_offline_strip', (
      tester,
    ) async {
      kit.home.topResult = const Result.failure(NetworkFailure());
      await pumpHome(tester);

      expect(
        find.text('Você está sem conexão. Mostrando o que já foi carregado.'),
        findsOneWidget,
      );
    });
  });

  group('HomeView interaction', () {
    testWidgets('choosing_the_house_shows_the_card_by_person', (tester) async {
      await pumpHome(tester);
      expect(find.text('Gastos por pessoa'), findsNothing);

      await tester.tap(find.text('Casa'));
      await tester.pumpAndSettle();

      expect(find.text('Gastos por pessoa'), findsOneWidget);
      expect(find.text('Ana (você)'), findsOneWidget);
      expect(find.text('Bia'), findsWidgets);
    });

    testWidgets('the_options_of_a_couple_are_me_the_partner_and_the_house', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Eu'), findsOneWidget);
      expect(find.text('Bia'), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget);
    });

    testWidgets('with_more_people_the_options_become_chips', (tester) async {
      kit = HomeKit(users: const [ana, bia, caio]);
      await pumpHome(tester);

      expect(find.byType(ChoiceChip), findsNWidgets(4));
    });

    testWidgets('going_to_the_previous_month_changes_the_label', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();

      expect(find.text('Outubro 2026'), findsOneWidget);
      expect(find.text('Gasto em outubro'), findsOneWidget);
      // Past months are whole: no "until yesterday".
      expect(find.text('Média de R\$ 100,00 por dia'), findsOneWidget);
    });

    testWidgets('the_next_month_arrow_is_off_on_the_current_month', (
      tester,
    ) async {
      await pumpHome(tester);

      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      expect(next.onPressed, isNull);
    });

    testWidgets('the_ask_button_and_see_all_call_their_callbacks', (
      tester,
    ) async {
      var chat = 0;
      var entries = 0;
      await pumpHome(
        tester,
        onOpenChat: () => chat++,
        onOpenEntries: () => entries++,
      );

      await tester.tap(find.text('Perguntar ao Tally'));
      await tester.tap(find.text('Ver todos'));

      expect((chat, entries), (1, 1));
    });

    testWidgets('the_refresh_button_loads_the_numbers_again', (tester) async {
      await pumpHome(tester);
      kit.home.calls.clear();

      await tester.tap(find.byTooltip('Atualizar dados'));
      await tester.pumpAndSettle();

      expect(kit.home.calls, isNotEmpty);
    });

    testWidgets('logout_in_the_avatar_menu_closes_the_session', (tester) async {
      await pumpHome(tester);
      kit.session.onLoggedIn();

      await tester.tap(find.byTooltip('Abrir perfil e configurações'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pump();
      await tester.pump();

      expect(kit.auth.logouts, 1);
      expect(kit.session.isLoggedIn, isFalse);
      // The person and the choice are forgotten: the next login starts clean.
      expect(kit.scope.profileData, isNull);
      // In the app the router leaves this screen. Here the skeleton keeps
      // pulsing, so the test ends by removing it.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
