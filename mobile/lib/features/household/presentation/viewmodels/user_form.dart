import 'package:mobile/features/household/domain/entities/pluggy_credentials.dart';
import 'package:mobile/features/household/domain/entities/user_changes.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';

/// The fields of the user forms that are typed (and so can be wrong).
enum UserFormField { firstName, email, password, clientId, clientSecret }

/// Why a typed field was refused.
enum UserFormError { required, invalidEmail, shortPassword, invalidClientId }

/// What a form became: the [value] when everything is valid, otherwise the
/// [errors] of the fields that are not.
class UserFormResult<T> {
  const UserFormResult({this.value, this.errors = const {}});

  final T? value;
  final Map<UserFormField, UserFormError> errors;

  bool get isValid => value != null;
}

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Shortest password the API accepts.
const minPasswordLength = 8;

String? _blankToNull(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

void _checkName(
  String firstName,
  String email,
  Map<UserFormField, UserFormError> errors,
) {
  if (firstName.trim().isEmpty) {
    errors[UserFormField.firstName] = UserFormError.required;
  }
  final mail = email.trim();
  if (mail.isEmpty) {
    errors[UserFormField.email] = UserFormError.required;
  } else if (!_email.hasMatch(mail)) {
    errors[UserFormField.email] = UserFormError.invalidEmail;
  }
}

void _checkCredentials(
  String clientId,
  String clientSecret,
  Map<UserFormField, UserFormError> errors,
) {
  final id = clientId.trim();
  if (id.isEmpty) {
    errors[UserFormField.clientId] = UserFormError.required;
  } else if (!_uuid.hasMatch(id)) {
    errors[UserFormField.clientId] = UserFormError.invalidClientId;
  }
  if (clientSecret.trim().isEmpty) {
    errors[UserFormField.clientSecret] = UserFormError.required;
  }
}

/// Checks the "Editar usuário" form. Last name and nickname are optional.
UserFormResult<UserChanges> validateUserEdit({
  required String firstName,
  required String lastName,
  required String surname,
  required String email,
}) {
  final errors = <UserFormField, UserFormError>{};
  _checkName(firstName, email, errors);
  if (errors.isNotEmpty) return UserFormResult(errors: errors);
  return UserFormResult(
    value: UserChanges(
      firstName: firstName.trim(),
      lastName: _blankToNull(lastName),
      surname: _blankToNull(surname),
      email: email.trim(),
    ),
  );
}

/// Checks the "Novo usuário" form: the person and the credentials of their
/// Pluggy application.
UserFormResult<UserDraft> validateNewUser({
  required String firstName,
  required String lastName,
  required String surname,
  required String email,
  required String password,
  required String clientId,
  required String clientSecret,
}) {
  final errors = <UserFormField, UserFormError>{};
  _checkName(firstName, email, errors);
  if (password.isEmpty) {
    errors[UserFormField.password] = UserFormError.required;
  } else if (password.length < minPasswordLength) {
    errors[UserFormField.password] = UserFormError.shortPassword;
  }
  _checkCredentials(clientId, clientSecret, errors);
  if (errors.isNotEmpty) return UserFormResult(errors: errors);
  return UserFormResult(
    value: UserDraft(
      firstName: firstName.trim(),
      lastName: _blankToNull(lastName),
      surname: _blankToNull(surname),
      email: email.trim(),
      password: password,
      pluggyClientId: clientId.trim(),
      pluggyClientSecret: clientSecret.trim(),
    ),
  );
}

/// Checks the form that replaces the Pluggy credentials of a person.
UserFormResult<PluggyCredentials> validatePluggyCredentials({
  required String clientId,
  required String clientSecret,
}) {
  final errors = <UserFormField, UserFormError>{};
  _checkCredentials(clientId, clientSecret, errors);
  if (errors.isNotEmpty) return UserFormResult(errors: errors);
  return UserFormResult(
    value: PluggyCredentials(
      clientId: clientId.trim(),
      clientSecret: clientSecret.trim(),
    ),
  );
}
