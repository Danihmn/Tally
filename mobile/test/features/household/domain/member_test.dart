import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

void main() {
  const ana = Member(id: 'm1', firstName: 'Ana', householdId: 'h1');

  group('Member.displayName', () {
    test('is_the_nickname_when_there_is_one', () {
      final member = Member(
        id: ana.id,
        firstName: 'Ana',
        surname: 'Aninha',
        householdId: 'h1',
      );

      expect(member.displayName, 'Aninha');
    });

    test('falls_back_to_the_first_name_without_a_nickname', () {
      expect(ana.displayName, 'Ana');
      expect(
        const Member(
          id: 'm1',
          firstName: 'Ana',
          surname: '  ',
          householdId: 'h1',
        ).displayName,
        'Ana',
      );
    });
  });

  group('Member.initial', () {
    test('comes_from_the_nickname', () {
      const member = Member(
        id: 'm1',
        firstName: 'Ana',
        surname: 'bia',
        householdId: 'h1',
      );

      expect(member.initial, 'B');
    });

    test('is_a_question_mark_for_an_empty_name', () {
      expect(
        const Member(id: 'm1', firstName: '', householdId: 'h1').initial,
        '?',
      );
    });
  });

  group('Member.fullName', () {
    test('joins_first_and_last_name', () {
      const member = Member(
        id: 'm1',
        firstName: 'Ana',
        lastName: 'Souza',
        householdId: 'h1',
      );

      expect(member.fullName, 'Ana Souza');
      expect(ana.fullName, 'Ana');
    });
  });
}
