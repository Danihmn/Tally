import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

/// What the entry detail screen needs, handed over by the list (there is no
/// extra request: the list item has everything).
class EntryDetailArgs {
  const EntryDetailArgs({
    required this.entry,
    required this.account,
    required this.owner,
    required this.ownerColorIndex,
  });

  final FinancialEntry entry;

  /// The account the entry is paid with, or `null` if it has none.
  final BankAccount? account;

  /// The person the entry belongs to, or `null` if it is not known.
  final Member? owner;

  /// The place of the owner in the list of the house, which gives the color.
  final int ownerColorIndex;
}
