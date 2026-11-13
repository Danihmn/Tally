import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/presentation/views/transaction_detail_args.dart';
import 'package:mobile/features/transactions/presentation/views/transactions_view.dart';
import 'package:mobile/features/transactions/presentation/widgets/transaction_row.dart';

import '../../../support/pump_app.dart';
import '../../../support/transaction_factory.dart';
import '../../../support/transactions_kit.dart';

void main() {
  late TransactionsKit kit;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() => kit = TransactionsKit());
  tearDown(() => kit.session.dispose());

  Future<void> pumpView(
    WidgetTester tester, {
    ValueChanged<TransactionDetailArgs>? onOpenDetail,
    VoidCallback? onOpenAccounts,
    double height = 4000,
  }) async {
    tester.view.physicalSize = Size(800, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      TransactionsView(
        createViewModel: () => kit.viewModel,
        onOpenDetail: onOpenDetail,
        onOpenAccounts: onOpenAccounts,
      ),
    );
    await tester.pumpAndSettle();
  }

  void useFew() {
    kit.transactions.all = [
      makeTransaction(
        id: 'x1',
        description: 'Netflix.com',
        amount: '-169.80',
        date: DateTime.utc(2026, 11, 12),
        merchantName: 'Netflix',
        category: 'Video streaming',
      ),
      makeTransaction(
        id: 'x2',
        description: 'Salário',
        amount: '5000.00',
        direction: TransactionDirection.credit,
        date: DateTime.utc(2026, 11, 11),
        status: TransactionStatus.pending,
      ),
    ];
  }

  group('TransactionsView list', () {
    testWidgets('groups_by_day_with_relative_labels_and_the_day_total', (
      tester,
    ) async {
      useFew();
      await pumpView(tester);

      expect(find.text('Ontem'), findsOneWidget);
      expect(find.text('Qua, 11/11'), findsOneWidget);
      expect(find.text('Netflix.com'), findsOneWidget);
      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('Mostrando 2 de 2'), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);
    });

    testWidgets('shows_the_account_name_and_merchant_in_the_row', (
      tester,
    ) async {
      useFew();
      await pumpView(tester);

      expect(find.text('Netflix · Nubank'), findsOneWidget);
      expect(find.text('Video streaming'), findsWidgets);
    });

    testWidgets('scrolling_to_the_end_loads_more_and_shows_the_end', (
      tester,
    ) async {
      await pumpView(tester, height: 1000);
      expect(find.text('Mostrando 30 de 75'), findsOneWidget);

      final list = find.byType(ListView);
      for (var i = 0; i < 12; i++) {
        await tester.fling(list, const Offset(0, -3000), 5000);
        await tester.pumpAndSettle();
      }

      expect(find.text('Fim da lista'), findsOneWidget);

      // The count is the first item of the list: go back up to see it.
      await tester.dragUntilVisible(
        find.text('Mostrando 75 de 75'),
        list,
        const Offset(0, 500),
      );
      expect(find.text('Mostrando 75 de 75'), findsOneWidget);
    });

    testWidgets('tapping_a_row_opens_the_detail_with_account_and_owner', (
      tester,
    ) async {
      useFew();
      TransactionDetailArgs? opened;
      await pumpView(tester, onOpenDetail: (args) => opened = args);

      await tester.tap(find.byType(TransactionRow).first);

      expect(opened?.transaction.id, 'x1');
      expect(opened?.account?.marketingName, 'Nubank');
      expect(opened?.owner?.firstName, 'Ana');
    });

    testWidgets('an_error_shows_retry_and_retry_loads_the_list', (
      tester,
    ) async {
      kit.transactions.forced = const Result.failure(NetworkFailure());
      await pumpView(tester);
      expect(find.text('Tentar novamente'), findsOneWidget);

      kit.transactions.forced = null;
      useFew();
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Netflix.com'), findsOneWidget);
    });

    testWidgets('an_empty_answer_shows_the_empty_card_without_filters', (
      tester,
    ) async {
      kit.transactions.forced = Result.success(
        PageResult<Transaction>(
          items: const [],
          limit: 30,
          offset: 0,
          total: 0,
        ),
      );
      await pumpView(tester);

      expect(find.text('Nenhuma transação encontrada'), findsOneWidget);
      expect(find.text('Limpar busca e filtros'), findsNothing);
    });
  });

  group('TransactionsView search and filters', () {
    testWidgets('typing_in_the_search_filters_after_the_pause', (tester) async {
      useFew();
      await pumpView(tester);

      await tester.enterText(find.byType(TextField), 'netflix');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Netflix.com'), findsOneWidget);
      expect(find.text('Salário'), findsNothing);
      expect(kit.transactions.calls.last.search, 'netflix');
    });

    testWidgets('nothing_found_offers_to_clear_search_and_filters', (
      tester,
    ) async {
      useFew();
      await pumpView(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma transação encontrada'), findsOneWidget);

      await tester.tap(find.text('Limpar busca e filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Netflix.com'), findsOneWidget);
    });

    testWidgets('applying_a_filter_shows_a_chip_and_removing_it_reloads', (
      tester,
    ) async {
      useFew();
      await pumpView(tester);

      await tester.tap(find.byTooltip('Abrir filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Débito'));
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Débitos'), findsOneWidget);
      expect(kit.transactions.calls.last.filters.direction, isNotNull);

      await tester.tap(find.byTooltip('Remover filtro Débitos'));
      await tester.pumpAndSettle();

      expect(find.text('Débitos'), findsNothing);
      expect(kit.transactions.calls.last.filters.isEmpty, isTrue);
    });
  });

  group('TransactionsView scope', () {
    testWidgets('a_person_without_bank_sees_the_no_bank_card', (tester) async {
      kit.accounts.result = Result.success(
        (await kit.accounts.getAccounts()).when(
          success: (list) => list.where((a) => a.ownerId == 'm1').toList(),
          failure: (_) => const [],
        ),
      );
      var opened = false;
      await pumpView(tester, onOpenAccounts: () => opened = true);

      await tester.tap(find.text('Bia'));
      await tester.pumpAndSettle();

      expect(find.text('Bia ainda não conectou um banco'), findsOneWidget);
      await tester.tap(find.text('Ver contas e conexões'));
      expect(opened, isTrue);
    });
  });
}
