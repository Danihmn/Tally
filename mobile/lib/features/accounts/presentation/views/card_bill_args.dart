import 'package:mobile/features/accounts/domain/entities/account_balance.dart';

/// What the Contas tab hands to the bill screen: the card that was tapped.
class CardBillArgs {
  const CardBillArgs({required this.account});

  final AccountBalance account;
}
