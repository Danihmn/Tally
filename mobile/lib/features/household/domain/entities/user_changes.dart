import 'package:equatable/equatable.dart';

/// What the edit form sends for a person: the four fields it shows. A
/// [lastName] or [surname] left out (`null`) clears it.
class UserChanges extends Equatable {
  const UserChanges({
    required this.firstName,
    required this.email,
    this.lastName,
    this.surname,
  });

  final String firstName;
  final String? lastName;

  /// The nickname ("apelido").
  final String? surname;
  final String email;

  @override
  List<Object?> get props => [firstName, lastName, surname, email];
}
