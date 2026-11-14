import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/views/entries_view.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_args.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_row.dart';

import '../../../support/entries_kit.dart';
import '../../../support/entry_factory.dart';
import '../../../support/pump_app.dart';

void main() {
  late EntriesKit kit;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() => kit = EntriesKit());
  tearDown(() => kit.session.dispose());

  Future<void> pumpView(
    WidgetTester tester, {
    ValueChanged<EntryDetailArgs>? onOpenDetail,
    double height = 4000,
  }) async {
    tester.view.physicalSize = Size(800, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      EntriesView(
        createViewModel: () => kit.viewModel,
        onOpenDetail: onOpenDetail,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('EntriesView list', () {
    testWidgets('shows_the_planned_entries_of_the_current_month', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('Luz'), findsNothing);
      expect(find.text('Mostrando 3 de 3'), findsOneWidget);
    });

    testWidgets('a_row_has_category_payment_dates_status_and_installment', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Moradia · Débito · Despesa'), findsWidgets);
      expect(find.text('Moradia · Crédito · Receita'), findsOneWidget);
      expect(find.text('Venc. 20/11 · Ref. nov'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
      expect(find.textContaining('1.500,00'), findsOneWidget);
    });

    testWidgets('a_planned_entry_past_its_due_date_is_overdue', (tester) async {
      await pumpView(tester);

      // Internet (10/11) and Salário (05/11) are past "today" (13/11).
      expect(find.text('Vencido'), findsNWidgets(2));
      expect(find.text('Planejado'), findsOneWidget);
    });

    testWidgets('the_tabs_show_the_count_of_each_status', (tester) async {
      await pumpView(tester);

      expect(find.text('Planejados 3'), findsOneWidget);
      expect(find.text('Conciliados 1'), findsOneWidget);
      expect(find.text('Cancelados 1'), findsOneWidget);
    });

    testWidgets('choosing_a_tab_shows_its_entries', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('Conciliados 1'));
      await tester.pumpAndSettle();

      expect(find.text('Luz'), findsOneWidget);
      expect(find.text('Conciliado'), findsOneWidget);
      expect(find.text('Aluguel'), findsNothing);

      await tester.tap(find.text('Cancelados 1'));
      await tester.pumpAndSettle();

      expect(find.text('Academia'), findsOneWidget);
      expect(find.text('Cancelado'), findsOneWidget);
    });

    testWidgets('tapping_a_row_opens_the_detail_with_account_and_owner', (
      tester,
    ) async {
      EntryDetailArgs? opened;
      await pumpView(tester, onOpenDetail: (args) => opened = args);

      await tester.tap(find.byType(EntryRow).first);

      expect(opened?.entry.id, 'e1');
      expect(opened?.account?.marketingName, 'Nubank');
      expect(opened?.owner?.firstName, 'Ana');
    });

    testWidgets('an_error_shows_retry_and_retry_loads_the_list', (
      tester,
    ) async {
      kit.entries.forced = const Result.failure(NetworkFailure());
      await pumpView(tester);
      expect(find.text('Tentar novamente'), findsOneWidget);

      kit.entries.forced = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Aluguel'), findsOneWidget);
    });

    testWidgets('there_is_no_button_to_create_an_entry', (tester) async {
      await pumpView(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Novo lançamento'), findsNothing);
    });
  });

  group('EntriesView month', () {
    testWidgets('the_current_month_is_selected_and_todos_is_a_chip', (
      tester,
    ) async {
      await pumpView(tester);

      final nov = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Nov'),
      );
      final todos = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Todos'),
      );
      expect(nov.selected, isTrue);
      expect(todos.selected, isFalse);
    });

    testWidgets('an_empty_month_says_which_tab_and_month', (tester) async {
      await pumpView(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Out'));
      await tester.pumpAndSettle();

      expect(
        find.text('Nenhum lançamento planejado em outubro'),
        findsOneWidget,
      );
    });

    testWidgets('todos_shows_every_month', (tester) async {
      await pumpView(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.pumpAndSettle();

      expect(find.text('Aluguel'), findsOneWidget);
      expect(kit.entries.calls.last.referenceMonth, isNull);
    });
  });

  group('EntriesView search and filters', () {
    testWidgets('typing_in_the_search_filters_after_the_pause', (tester) async {
      await pumpView(tester);

      await tester.enterText(find.byType(TextField), 'aluguel');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Internet'), findsNothing);
      expect(kit.entries.calls.last.search, 'aluguel');
    });

    testWidgets('nothing_found_offers_to_clear_search_and_filters', (
      tester,
    ) async {
      await pumpView(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Limpar busca e filtros'), findsOneWidget);

      await tester.tap(find.text('Limpar busca e filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Aluguel'), findsOneWidget);
    });

    testWidgets('applying_a_filter_shows_a_chip_and_removing_it_reloads', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(find.byTooltip('Abrir filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Receita'));
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Receitas'), findsOneWidget);
      expect(kit.entries.calls.last.filters.type, EntryType.revenues);

      await tester.tap(find.byTooltip('Remover filtro Receitas'));
      await tester.pumpAndSettle();

      expect(find.text('Receitas'), findsNothing);
      expect(kit.entries.calls.last.filters.isEmpty, isTrue);
    });

    testWidgets('the_entries_of_another_person_show_after_choosing_them', (
      tester,
    ) async {
      kit.entries.all = [
        makeEntry(id: 'x1', description: 'Do Eu'),
        makeEntry(id: 'x2', description: 'Da Bia', ownerId: 'm2'),
      ];
      await pumpView(tester);
      expect(find.text('Do Eu'), findsOneWidget);

      await tester.tap(find.text('Bia'));
      await tester.pumpAndSettle();

      expect(find.text('Da Bia'), findsOneWidget);
      expect(find.text('Do Eu'), findsNothing);
    });
  });
}
