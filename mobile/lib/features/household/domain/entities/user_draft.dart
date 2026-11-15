import 'package:equatable/equatable.dart';

/// A new person of the house, as the form collects it. [pluggyClientId] and
/// [pluggyClientSecret] are the credentials of the person's own Pluggy
/// application.
class UserDraft extends Equatable {
  const UserDraft({
    required this.firstName,
    required this.email,
    required this.password,
    required this.pluggyClientId,
    required this.pluggyClientSecret,
    this.lastName,
    this.surname,
  });

  final String firstName;
  final String? lastName;

  /// The nickname ("apelido").
  final String? surname;
  final String email;
  final String password;
  final String pluggyClientId;
  final String pluggyClientSecret;

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    surname,
    email,
    password,
    pluggyClientId,
    pluggyClientSecret,
  ];
}
