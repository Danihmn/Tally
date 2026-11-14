import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/accounts/domain/usecases/get_bank_accounts.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/usecases/search_entries.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

/// The entries matched with one bank transaction, for the "Lançamento
/// vinculado" block of the transaction detail. It loads by itself, so a
/// failure here never takes the rest of the screen down.
class LinkedEntriesViewModel extends ChangeNotifier {
  LinkedEntriesViewModel({
    required this._transactionId,
    required this._searchEntries,
    required this._getAccounts,
    required this._scopeController,
  });

  /// More than this per transaction is not expected; the screen shows them all.
  static const _pageSize = 20;

  final String _transactionId;
  final SearchEntries _searchEntries;
  final GetBankAccounts _getAccounts;
  final HouseholdScopeController _scopeController;

  UiState<List<FinancialEntry>> _state = const UiInitial();
  List<BankAccount> _accounts = const [];
  bool _disposed = false;

  UiState<List<FinancialEntry>> get state => _state;

  Future<void> load() async {
    _state = const UiLoading();
    _notify();
    final entriesFuture = _searchEntries(
      offset: 0,
      limit: _pageSize,
      transactionId: _transactionId,
    );
    final accountsFuture = _getAccounts();
    final result = await entriesFuture;
    final accounts = await accountsFuture;
    if (_disposed) return;
    _accounts = accounts.valueOrNull ?? const [];
    _state = result.when<UiState<List<FinancialEntry>>>(
      success: (page) =>
          page.items.isEmpty ? const UiEmpty() : UiSuccess(page.items),
      failure: UiError<List<FinancialEntry>>.new,
    );
    _notify();
  }

  BankAccount? accountOf(String? id) {
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// The person the entry belongs to, or `null` if unknown.
  Member? memberOf(String id) {
    final members = _scopeController.profileData?.members ?? const <Member>[];
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// The place of a person in the list of the house, which gives the color.
  int memberIndexOf(String id) {
    final members = _scopeController.profileData?.members ?? const <Member>[];
    final index = members.indexWhere((member) => member.id == id);
    return index < 0 ? 0 : index;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
