import 'package:mobile/features/household/domain/entities/pluggy_credentials.dart';
import 'package:mobile/features/household/domain/entities/user_changes.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';

extension UserDraftJson on UserDraft {
  /// The body of `POST /users`. The house comes from the login, not from here.
  Map<String, dynamic> toJson() => {
    'first_name': firstName.trim(),
    'last_name': lastName,
    'surname': surname,
    'email': email.trim(),
    'password': password,
    'pluggy_client_id': pluggyClientId.trim(),
    'pluggy_client_secret': pluggyClientSecret.trim(),
  };
}

extension UserChangesJson on UserChanges {
  /// The body of `PATCH /users/{id}`. Every key is sent, so a nickname or last
  /// name left empty is cleared (`null`).
  Map<String, dynamic> toJson() => {
    'first_name': firstName.trim(),
    'last_name': lastName,
    'surname': surname,
    'email': email.trim(),
  };
}

extension PluggyCredentialsJson on PluggyCredentials {
  /// The body of `PUT /users/{id}/pluggy-credentials`.
  Map<String, dynamic> toJson() => {
    'pluggy_client_id': clientId.trim(),
    'pluggy_client_secret': clientSecret.trim(),
  };
}
