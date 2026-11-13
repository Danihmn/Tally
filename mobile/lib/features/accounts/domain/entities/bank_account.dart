import 'package:equatable/equatable.dart';

/// A bank account or a credit card of the house.
class BankAccount extends Equatable {
  const BankAccount({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.marketingName,
    required this.number,
    required this.isCreditCard,
  });

  final String id;

  /// The person who connected the bank.
  final String ownerId;
  final String name;

  /// The name the bank shows to its clients, when there is one.
  final String? marketingName;
  final String number;
  final bool isCreditCard;

  /// What the screens call the account: the marketing name when it exists.
  String get displayName {
    final marketing = marketingName?.trim();
    return marketing == null || marketing.isEmpty ? name : marketing;
  }

  /// The last four digits of the number, for "Conta ••1234".
  String get shortNumber {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return number;
    return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    name,
    marketingName,
    number,
    isCreditCard,
  ];
}
