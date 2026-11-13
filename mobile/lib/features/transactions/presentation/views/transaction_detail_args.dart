import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';

/// What the detail screen needs, handed over by the list (there is no extra
/// request: the list item has everything).
class TransactionDetailArgs {
  const TransactionDetailArgs({
    required this.transaction,
    required this.account,
    required this.owner,
    required this.ownerColorIndex,
  });

  final Transaction transaction;

  /// The account, or `null` if it is not known.
  final BankAccount? account;

  /// The person who connected the bank, or `null` if it is not known.
  final Member? owner;

  /// The place of the owner in the list of the house, which gives the color.
  final int ownerColorIndex;
}
