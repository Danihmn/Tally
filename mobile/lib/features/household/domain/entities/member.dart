import 'package:equatable/equatable.dart';

/// A person of the household (one of the people who use the app).
class Member extends Equatable {
  const Member({
    required this.id,
    required this.firstName,
    required this.householdId,
    this.lastName,
    this.surname,
    this.email,
  });

  final String id;
  final String firstName;
  final String householdId;
  final String? lastName;

  /// The nickname ("apelido"). The API calls it `surname`.
  final String? surname;
  final String? email;

  /// The name the app shows for this person: the nickname, or the first name
  /// when there is none.
  String get displayName {
    final nickname = surname?.trim() ?? '';
    return nickname.isEmpty ? firstName : nickname;
  }

  /// First name and last name, for the places that have room for it.
  String get fullName {
    final last = lastName?.trim() ?? '';
    return last.isEmpty ? firstName : '$firstName $last';
  }

  /// First letter of [displayName], for the avatar.
  String get initial {
    final name = displayName;
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  @override
  List<Object?> get props => [
    id,
    firstName,
    householdId,
    lastName,
    surname,
    email,
  ];
}
