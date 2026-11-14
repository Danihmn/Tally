import 'package:flutter/foundation.dart';

/// A request from another screen to open the transactions list already
/// filtered by one account or card (for example "Ver transações" on the
/// Contas screen).
///
/// The transactions tab may not exist yet when the request is made (tabs are
/// built when first opened), so the request waits here until the list takes
/// it with [take]. If the list is already alive, it listens and reacts.
class TransactionsFilterRequest extends ChangeNotifier {
  String? _accountId;

  /// The account asked for and not taken yet, or `null`.
  String? get pendingAccountId => _accountId;

  void requestAccount(String accountId) {
    _accountId = accountId;
    notifyListeners();
  }

  /// Gives the waiting request to the list and clears it.
  String? take() {
    final id = _accountId;
    _accountId = null;
    return id;
  }
}
