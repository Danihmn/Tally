import 'package:equatable/equatable.dart';

/// A person of the household (one of the people who use the app).
class Member extends Equatable {
  const Member({
    required this.id,
    required this.firstName,
    required this.householdId,
  });

  final String id;
  final String firstName;
  final String householdId;

  /// First letter, for the avatar.
  String get initial =>
      firstName.isEmpty ? '?' : firstName.substring(0, 1).toUpperCase();

  @override
  List<Object?> get props => [id, firstName, householdId];
}
