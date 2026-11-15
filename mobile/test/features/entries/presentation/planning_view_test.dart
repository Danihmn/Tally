import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/features/entries/presentation/views/planning_view.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';

import '../../../support/pump_app.dart';

void main() {
  late ValueChanged<ProvisionResult> provision;

  Future<void> pumpPlanning(WidgetTester tester) async {
    await pumpApp(
      tester,
      PlanningView(
        entriesBuilder: (month) => _Section('lista de lançamentos', month),
        recurrencesBuilder: (onProvisioned) {
          provision = onProvisioned;
          return const _Section('lista de recorrências', null);
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  ProvisionResult result({int created = 2}) => ProvisionResult(
    referenceMonth: DateTime(2026, 12),
    created: created,
    skipped: 0,
  );

  testWidgets('opens_on_the_entries_with_the_screen_title', (tester) async {
    await pumpPlanning(tester);

    expect(find.text('Planejamento'), findsOneWidget);
    expect(find.text('lista de lançamentos'), findsOneWidget);
    expect(find.text('Lançamentos'), findsOneWidget);
    expect(find.text('Recorrências'), findsOneWidget);
  });

  testWidgets('the_recurrences_are_built_only_when_first_opened', (
    tester,
  ) async {
    await pumpPlanning(tester);
    expect(find.text('lista de recorrências'), findsNothing);

    await tester.tap(find.text('Recorrências'));
    await tester.pumpAndSettle();

    expect(find.text('lista de recorrências'), findsOneWidget);
  });

  testWidgets('switching_back_keeps_the_entries_where_they_were', (
    tester,
  ) async {
    await pumpPlanning(tester);
    final before = tester.state(find.byType(_Section).first);

    await tester.tap(find.text('Recorrências'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lançamentos'));
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(_Section).first), same(before));
  });

  testWidgets('provisioning_goes_back_to_the_entries_on_that_month', (
    tester,
  ) async {
    await pumpPlanning(tester);
    await tester.tap(find.text('Recorrências'));
    await tester.pumpAndSettle();

    provision(result());
    await tester.pumpAndSettle();

    final entries = tester.widget<_Section>(
      find.widgetWithText(_Section, 'lista de lançamentos'),
    );
    expect(entries.month, DateTime(2026, 12));
    expect(
      tester
          .widget<SegmentedButton<PlanningSection>>(
            find.byType(SegmentedButton<PlanningSection>),
          )
          .selected,
      {PlanningSection.entries},
    );
  });

  testWidgets('provisioning_that_created_nothing_stays_on_the_recurrences', (
    tester,
  ) async {
    await pumpPlanning(tester);
    await tester.tap(find.text('Recorrências'));
    await tester.pumpAndSettle();

    provision(result(created: 0));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SegmentedButton<PlanningSection>>(
            find.byType(SegmentedButton<PlanningSection>),
          )
          .selected,
      {PlanningSection.recurrences},
    );
  });
}

/// A stand-in for a section: it only shows its name.
class _Section extends StatefulWidget {
  const _Section(this.name, this.month);

  final String name;
  final DateTime? month;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  @override
  Widget build(BuildContext context) => Text(widget.name);
}
