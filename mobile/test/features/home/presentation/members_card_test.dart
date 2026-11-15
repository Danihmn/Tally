import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/features/home/domain/entities/spending_by_member.dart';
import 'package:mobile/features/home/presentation/widgets/members_card.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

import '../../../support/fake_home_repository.dart';
import '../../../support/pump_app.dart';

void main() {
  const ana = Member(id: 'm1', firstName: 'Ana', householdId: 'h');
  const bia = Member(id: 'm2', firstName: 'Bia', householdId: 'h');
  final spending = SpendingByMember([
    MemberSpending(member: ana, amount: dec('300.00')),
    MemberSpending(member: bia, amount: dec('100.00')),
  ]);

  group('MembersCard', () {
    testWidgets('shows_each_person_with_the_amount_and_the_percentage', (
      tester,
    ) async {
      await pumpApp(
        tester,
        MembersCard(spending: spending, members: const [ana, bia], meId: 'm1'),
      );

      expect(find.text('Ana (você)'), findsOneWidget);
      expect(find.text('R\$ 300,00'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Bia'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('2 pessoas'), findsOneWidget);
    });

    testWidgets('shows_only_the_nickname_of_each_person', (tester) async {
      const dudu = Member(
        id: 'm3',
        firstName: 'Eduardo',
        lastName: 'Souza',
        surname: 'Dudu',
        householdId: 'h',
      );
      final withNickname = SpendingByMember([
        MemberSpending(member: dudu, amount: dec('100.00')),
      ]);

      await pumpApp(
        tester,
        MembersCard(spending: withNickname, members: const [dudu], meId: 'm9'),
      );

      expect(find.text('Dudu'), findsOneWidget);
      expect(find.textContaining('Eduardo'), findsNothing);
      expect(find.textContaining('Souza'), findsNothing);
    });

    testWidgets('the_split_bar_has_a_visible_height_for_each_person', (
      tester,
    ) async {
      await pumpApp(
        tester,
        MembersCard(spending: spending, members: const [ana, bia], meId: 'm1'),
      );

      final segments = find.descendant(
        of: find.byKey(const Key('membersSplitBar')),
        matching: find.byType(ColoredBox),
      );
      expect(segments, findsNWidgets(2));
      for (final element in segments.evaluate()) {
        expect(tester.getSize(find.byWidget(element.widget)).height, 14);
      }
    });

    testWidgets('a_person_who_spent_nothing_has_no_segment_in_the_bar', (
      tester,
    ) async {
      final onlyAna = SpendingByMember([
        MemberSpending(member: ana, amount: dec('300.00')),
        MemberSpending(member: bia, amount: dec('0.00')),
      ]);
      await pumpApp(
        tester,
        MembersCard(spending: onlyAna, members: const [ana, bia], meId: 'm1'),
      );

      final segments = find.descendant(
        of: find.byKey(const Key('membersSplitBar')),
        matching: find.byType(ColoredBox),
      );
      expect(segments, findsOneWidget);
    });
  });
}
