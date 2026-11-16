import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';
import 'package:mobile/features/household/presentation/viewmodels/user_form.dart';

void main() {
  const goodId = '11111111-2222-3333-4444-555555555555';

  UserFormResult<UserDraft> newUser({
    String firstName = 'Carla',
    String lastName = '',
    String surname = '',
    String email = 'carla@casa.com',
    String password = 'segredo123',
    String clientId = goodId,
    String clientSecret = 's3cr3t',
  }) => validateNewUser(
    firstName: firstName,
    lastName: lastName,
    surname: surname,
    email: email,
    password: password,
    clientId: clientId,
    clientSecret: clientSecret,
  );

  group('validateUserEdit', () {
    test('a_filled_form_becomes_the_changes_with_blanks_as_null', () {
      final result = validateUserEdit(
        firstName: ' Ana ',
        lastName: '  ',
        surname: ' Aninha ',
        email: ' ana@casa.com ',
      );

      expect(result.isValid, isTrue);
      expect(result.value!.firstName, 'Ana');
      expect(result.value!.lastName, isNull);
      expect(result.value!.surname, 'Aninha');
      expect(result.value!.email, 'ana@casa.com');
    });

    test('the_first_name_and_the_email_are_required', () {
      final result = validateUserEdit(
        firstName: ' ',
        lastName: '',
        surname: '',
        email: '',
      );

      expect(result.errors, {
        UserFormField.firstName: UserFormError.required,
        UserFormField.email: UserFormError.required,
      });
      expect(result.isValid, isFalse);
    });

    test('an_email_without_an_at_sign_is_refused', () {
      final result = validateUserEdit(
        firstName: 'Ana',
        lastName: '',
        surname: '',
        email: 'ana.casa.com',
      );

      expect(result.errors, {UserFormField.email: UserFormError.invalidEmail});
    });
  });

  group('validateNewUser', () {
    test('a_filled_form_becomes_the_draft', () {
      final result = newUser(surname: 'Cacá');

      expect(result.isValid, isTrue);
      final draft = result.value!;
      expect(draft.firstName, 'Carla');
      expect(draft.surname, 'Cacá');
      expect(draft.pluggyClientId, goodId);
      expect(draft.pluggyClientSecret, 's3cr3t');
    });

    test('the_password_needs_at_least_8_characters', () {
      expect(newUser(password: '1234567').errors, {
        UserFormField.password: UserFormError.shortPassword,
      });
      expect(newUser(password: '12345678').isValid, isTrue);
      expect(newUser(password: '').errors, {
        UserFormField.password: UserFormError.required,
      });
    });

    test('the_client_id_must_be_a_uuid', () {
      expect(newUser(clientId: 'not-a-uuid').errors, {
        UserFormField.clientId: UserFormError.invalidClientId,
      });
      expect(newUser(clientId: '').errors, {
        UserFormField.clientId: UserFormError.required,
      });
    });

    test('the_client_secret_is_required', () {
      expect(newUser(clientSecret: '  ').errors, {
        UserFormField.clientSecret: UserFormError.required,
      });
    });

    test('every_wrong_field_is_reported_at_once', () {
      final result = newUser(
        firstName: '',
        email: 'x',
        password: '1',
        clientId: 'x',
        clientSecret: '',
      );

      expect(result.errors.keys, UserFormField.values);
    });
  });

  group('validatePluggyCredentials', () {
    test('a_uuid_and_a_secret_are_enough', () {
      final result = validatePluggyCredentials(
        clientId: ' $goodId ',
        clientSecret: ' secret ',
      );

      expect(result.isValid, isTrue);
      expect(result.value!.clientId, goodId);
      expect(result.value!.clientSecret, 'secret');
    });

    test('both_fields_are_checked', () {
      final result = validatePluggyCredentials(clientId: 'x', clientSecret: '');

      expect(result.errors, {
        UserFormField.clientId: UserFormError.invalidClientId,
        UserFormField.clientSecret: UserFormError.required,
      });
    });
  });

  group('validatePassword', () {
    test('a_long_enough_password_is_kept_as_typed', () {
      final result = validatePassword(' new pass ');

      expect(result.isValid, isTrue);
      expect(result.value, ' new pass ');
    });

    test('an_empty_password_is_required', () {
      expect(validatePassword('').errors, {
        UserFormField.password: UserFormError.required,
      });
    });

    test('a_short_password_is_refused', () {
      expect(validatePassword('1234567').errors, {
        UserFormField.password: UserFormError.shortPassword,
      });
    });
  });
}
