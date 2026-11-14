import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_filter_sheet.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

import '../../../support/fake_transactions_repository.dart';
import '../../../support/pump_app.dart';
import '../../../support/transactions_kit.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  const me = ScopeOption.me(ana);
  final options = [
    const ScopeOption.house(),
    me,
    const ScopeOption.person(bia),
  ];
  final accounts = FakeAccountsRepository().result.when<List<BankAccount>>(
    success: (list) => list,
    failure: (_) => const [],
  );

  EntryFilterSheetResult? result;

  Future<void> openSheet(
    WidgetTester tester, {
    EntryFilters filters = const EntryFilters(),
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    result = null;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await EntryFilterSheet.show(
              context,
              filters: filters,
              accounts: accounts,
              scopeOptions: options,
              scope: me,
            );
          },
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('EntryFilterSheet', () {
    testWidgets('has_no_category_filter', (tester) async {
      await openSheet(tester);

      expect(find.text('Filtrar lançamentos'), findsOneWidget);
      expect(find.textContaining('Categoria'), findsNothing);
    });

    testWidgets('lists_the_house_first_then_me_then_the_others', (
      tester,
    ) async {
      await openSheet(tester);

      final house = tester.getTopLeft(find.text('Casa')).dx;
      final mine = tester.getTopLeft(find.text('Eu')).dx;
      final other = tester.getTopLeft(find.text('Bia')).dx;
      expect(house, lessThan(mine));
      expect(mine, lessThan(other));
    });

    testWidgets('shows_the_filters_already_applied', (tester) async {
      await openSheet(
        tester,
        filters: EntryFilters(
          dueFrom: DateTime(2026, 11),
          minAmount: Decimal.parse('100'),
        ),
      );

      expect(find.text('01/11/2026'), findsOneWidget);
      expect(find.text('100,00'), findsOneWidget);
    });

    testWidgets('applying_returns_the_chosen_filters_and_person', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.text('Receita'));
      await tester.tap(find.text('Crédito'));
      await tester.tap(find.text('Inter'));
      await tester.tap(find.text('Bia'));
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(result?.filters.type, EntryType.revenues);
      expect(result?.filters.paymentType, PaymentType.credit);
      expect(result?.filters.accountId, 'a3');
      expect(result?.scope, const ScopeOption.person(bia));
    });

    testWidgets('a_bad_date_keeps_the_sheet_open_with_the_error', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.enterText(find.widgetWithText(TextField, 'De'), '3');
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Use o formato dd/mm/aaaa.'), findsOneWidget);
      expect(find.text('Filtrar lançamentos'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('reset_clears_the_fields', (tester) async {
      await openSheet(
        tester,
        filters: EntryFilters(dueFrom: DateTime(2026, 11)),
      );

      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();

      expect(find.text('01/11/2026'), findsNothing);
    });
  });
}
