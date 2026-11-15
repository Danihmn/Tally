import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/presentation/views/recurrences_view.dart';
import 'package:mobile/features/recurrences/presentation/widgets/recurrence_form_sheet.dart';
import 'package:mobile/features/recurrences/presentation/widgets/recurrence_row.dart';

import '../../../support/pump_app.dart';
import '../../../support/recurrences_kit.dart';

void main() {
  late RecurrencesKit kit;
  late List<ProvisionResult> provisioned;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    kit = RecurrencesKit();
    provisioned = [];
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      RecurrencesView(
        createViewModel: () => kit.viewModel,
        onProvisioned: provisioned.add,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder sheetField(int index) => find
      .descendant(
        of: find.byType(RecurrenceFormSheet),
        matching: find.byType(TextField),
      )
      .at(index);

  group('RecurrencesView list', () {
    testWidgets('shows_each_recurrence_with_its_data', (tester) async {
      await pumpView(tester);

      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('Moradia · Débito · Despesa'), findsOneWidget);
      expect(find.text('Crédito · Receita'), findsOneWidget);
      expect(find.text('Todo dia 5'), findsOneWidget);
      expect(find.text('Sem dia fixo'), findsOneWidget);
      expect(find.textContaining('1.500,00'), findsOneWidget);
      expect(find.textContaining('5.000,00'), findsOneWidget);
    });

    testWidgets('with_none_it_invites_to_register_one', (tester) async {
      kit.repository.all = [];

      await pumpView(tester);

      expect(find.text('Nenhuma recorrência ainda'), findsOneWidget);
      // Provisioning is still offered: the API answers that there is nothing.
      expect(find.text('Provisionar dezembro'), findsOneWidget);
    });

    testWidgets('an_error_shows_retry_and_retry_loads_the_list', (
      tester,
    ) async {
      kit.repository.failure = const NetworkFailure();
      await pumpView(tester);
      expect(find.text('Tentar novamente'), findsOneWidget);

      kit.repository.failure = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Aluguel'), findsOneWidget);
    });
  });

  group('RecurrencesView create and edit', () {
    testWidgets('the_new_button_saves_a_recurrence', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('Nova recorrência'));
      await tester.pumpAndSettle();
      await tester.enterText(sheetField(0), 'Internet');
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '120');
      await tester.enterText(sheetField(3), '10');
      await tester.tap(find.text('Salvar recorrência'));
      await tester.pumpAndSettle();

      final draft = kit.repository.created.single;
      expect(draft.description, 'Internet');
      expect(draft.amount.toString(), '120');
      expect(draft.dueDay, 10);
      expect(find.text('Recorrência salva.'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
    });

    testWidgets('an_empty_form_says_what_is_missing', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('Nova recorrência'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar recorrência'));
      await tester.pumpAndSettle();

      expect(find.text('Preencha este campo.'), findsNWidgets(2));
      expect(kit.repository.created, isEmpty);
    });

    testWidgets('a_day_out_of_range_is_refused', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('Nova recorrência'));
      await tester.pumpAndSettle();
      await tester.enterText(sheetField(0), 'Internet');
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '120');
      await tester.enterText(sheetField(3), '45');
      await tester.tap(find.text('Salvar recorrência'));
      await tester.pumpAndSettle();

      expect(find.text('Digite um dia de 1 a 31.'), findsOneWidget);
      expect(kit.repository.created, isEmpty);
    });

    testWidgets('a_failure_keeps_the_form_open_and_says_why', (tester) async {
      await pumpView(tester);
      kit.repository.failure = const ServerUnavailableFailure();

      await tester.tap(find.text('Nova recorrência'));
      await tester.pumpAndSettle();
      await tester.enterText(sheetField(0), 'Internet');
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '120');
      await tester.tap(find.text('Salvar recorrência'));
      await tester.pumpAndSettle();

      expect(
        find.text('Serviço indisponível. Tente novamente em instantes.'),
        findsOneWidget,
      );
      expect(find.text('Nova recorrência'), findsWidgets);
    });

    testWidgets('tapping_a_row_edits_it_starting_from_its_data', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(find.byType(RecurrenceRow).first);
      await tester.pumpAndSettle();
      expect(find.text('Editar recorrência'), findsOneWidget);
      expect(
        tester.widget<TextField>(sheetField(0)).controller?.text,
        'Aluguel',
      );
      await tester.enterText(sheetField(0), 'Aluguel novo');
      await tester.tap(find.text('Salvar recorrência'));
      await tester.pumpAndSettle();

      final (id, draft) = kit.repository.updated.single;
      expect(id, 'r1');
      expect(draft.description, 'Aluguel novo');
      expect(draft.dueDay, 5);
      expect(find.text('Aluguel novo'), findsOneWidget);
    });
  });

  group('RecurrencesView delete', () {
    Future<void> openDeleteDialog(WidgetTester tester) async {
      await tester.tap(find.byType(PopupMenuButton<RecurrenceAction>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir recorrência'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks_first_and_does_nothing_if_the_person_backs_out', (
      tester,
    ) async {
      await pumpView(tester);

      await openDeleteDialog(tester);
      expect(find.text('Excluir recorrência?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(kit.repository.deleted, isEmpty);
      expect(find.text('Aluguel'), findsOneWidget);
    });

    testWidgets('confirming_removes_the_recurrence', (tester) async {
      await pumpView(tester);

      await openDeleteDialog(tester);
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(kit.repository.deleted, ['r1']);
      expect(find.text('Aluguel'), findsNothing);
      expect(find.text('Recorrência excluída.'), findsOneWidget);
    });
  });

  group('RecurrencesView provision', () {
    testWidgets('the_button_names_the_next_month', (tester) async {
      await pumpView(tester);

      expect(find.text('Provisionar dezembro'), findsOneWidget);
    });

    testWidgets('asks_for_confirmation_before_provisioning', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('Provisionar dezembro'));
      await tester.pumpAndSettle();

      expect(find.text('Provisionar o próximo mês?'), findsOneWidget);
      expect(
        find.textContaining(
          'lançamentos de dezembro a partir das recorrências',
        ),
        findsOneWidget,
      );
      expect(kit.repository.provisionCalls, 0);
    });

    testWidgets('backing_out_of_the_dialog_does_not_provision', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('Provisionar dezembro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(kit.repository.provisionCalls, 0);
      expect(provisioned, isEmpty);
    });

    testWidgets('confirming_provisions_says_how_many_and_tells_the_screen', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(find.text('Provisionar dezembro'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Provisionar'));
      await tester.pumpAndSettle();

      expect(kit.repository.provisionCalls, 1);
      expect(find.text('2 lançamentos criados em dezembro.'), findsOneWidget);
      expect(provisioned.single.created, 2);
      expect(provisioned.single.referenceMonth, DateTime(2026, 12));
    });

    testWidgets('when_everything_was_already_provisioned_it_says_so', (
      tester,
    ) async {
      kit.repository.provision = Result.success(
        ProvisionResult(
          referenceMonth: DateTime(2026, 12),
          created: 0,
          skipped: 2,
        ),
      );
      await pumpView(tester);

      await tester.tap(find.text('Provisionar dezembro'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Provisionar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Tudo já estava provisionado em dezembro.'),
        findsOneWidget,
      );
    });

    testWidgets('without_recurrences_the_message_says_to_register_one', (
      tester,
    ) async {
      kit.repository.provision = const Result.failure(NoRecurrencesFailure());
      await pumpView(tester);

      await tester.tap(find.text('Provisionar dezembro'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Provisionar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Cadastre ao menos uma recorrência antes de provisionar o mês.',
        ),
        findsOneWidget,
      );
      expect(provisioned, isEmpty);
    });

    testWidgets('another_failure_shows_its_own_message', (tester) async {
      kit.repository.provision = const Result.failure(NetworkFailure());
      await pumpView(tester);

      await tester.tap(find.text('Provisionar dezembro'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Provisionar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sem conexão. Verifique sua internet e tente de novo.'),
        findsOneWidget,
      );
    });
  });
}
