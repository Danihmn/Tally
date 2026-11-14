import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// Bank account (checking, savings) or credit card.
enum AccountKind {
  bank('BANK'),
  credit('CREDIT');

  const AccountKind(this.apiValue);

  /// What the API sends and expects in the `type` field.
  final String apiValue;
}

/// What the bank tells about a credit card. Every field may be missing.
class CreditInfo extends Equatable {
  const CreditInfo({
    required this.creditLimit,
    required this.availableCreditLimit,
    required this.dueDate,
    required this.closeDate,
  });

  final Decimal? creditLimit;

  /// What is still free to spend, as the bank says (not calculated here).
  final Decimal? availableCreditLimit;
  final DateTime? dueDate;
  final DateTime? closeDate;

  /// How much of the limit is used, from 0 to 1, for the bar of the card.
  /// `null` when there is no limit to compare with. It is only a size for the
  /// bar: the money on screen never goes through `double`.
  double? usedShare(Decimal balance) {
    final limit = creditLimit;
    if (limit == null || limit <= Decimal.zero) return null;
    final share = (balance / limit).toDouble();
    return share.clamp(0.0, 1.0).toDouble();
  }

  @override
  List<Object?> get props => [
    creditLimit,
    availableCreditLimit,
    dueDate,
    closeDate,
  ];
}

/// An account or a card of the house with the balance the bank gave in its
/// last sync. The balance of an account is what can be spent (it can be
/// negative); the balance of a card is the open bill.
class AccountBalance extends Equatable {
  const AccountBalance({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.name,
    required this.marketingName,
    required this.number,
    required this.balance,
    required this.credit,
  });

  final String id;

  /// The person who connected the bank.
  final String ownerId;
  final AccountKind kind;
  final String name;
  final String? marketingName;
  final String number;

  /// `null` when the bank did not give it (it then counts as zero in totals).
  final Decimal? balance;

  /// Only for cards, and only when the bank sent the credit data.
  final CreditInfo? credit;

  bool get isCreditCard => kind == AccountKind.credit;

  /// What the screens call the account: the marketing name when it exists.
  String get displayName {
    final marketing = marketingName?.trim();
    return marketing == null || marketing.isEmpty ? name : marketing;
  }

  /// The last four digits of the number, for "•••• 1234".
  String get shortNumber {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return number;
    return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    kind,
    name,
    marketingName,
    number,
    balance,
    credit,
  ];
}
