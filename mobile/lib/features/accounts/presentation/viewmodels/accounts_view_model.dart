import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/features/accounts/domain/usecases/get_account_balances.dart';
import 'package:mobile/features/accounts/domain/usecases/get_total_balance.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

/// State of the Contas screen.
///
/// Three things load at the same time and each one has its own state, so one
/// failing does not hide the others: the total of the accounts, the total of
/// the open bills of the cards, and the list of accounts and cards. The person
/// is the one shared with the other screens. The balances are the ones the
/// bank gave in its last sync (nothing is calculated here).
class AccountsViewModel extends ChangeNotifier {
  AccountsViewModel({
    required this._scopeController,
    required this._getBalances,
    required this._getTotal,
  }) {
    _scopeController.addListener(_onScopeChanged);
  }

  final HouseholdScopeController _scopeController;
  final GetAccountBalances _getBalances;
  final GetTotalBalance _getTotal;

  AccountKind _tab = AccountKind.bank;
  UiState<List<AccountBalance>> _list = const UiInitial();
  UiState<Decimal> _bankTotal = const UiInitial();
  UiState<Decimal> _cardTotal = const UiInitial();
  int _generation = 0;
  bool _disposed = false;

  /// The choice that the data on screen was loaded for.
  ScopeOption? _appliedScope;

  /// The reload that the last change of the choice started.
  Future<void>? _scopeReload;

  UiState<HouseholdProfile> get profile => _scopeController.profile;

  HouseholdProfile? get profileData => _scopeController.profileData;

  List<ScopeOption> get scopeOptions => _scopeController.scopeOptions;

  ScopeOption? get scope => _scopeController.scope;

  AccountKind get tab => _tab;

  UiState<List<AccountBalance>> get list => _list;

  /// The sum of the balances of the accounts.
  UiState<Decimal> get bankTotal => _bankTotal;

  /// The sum of the open bills of the cards.
  UiState<Decimal> get cardTotal => _cardTotal;

  List<AccountBalance> get _all => switch (_list) {
    UiSuccess<List<AccountBalance>>(:final data) => data,
    _ => const [],
  };

  List<AccountBalance> get banks => [
    for (final a in _all)
      if (!a.isCreditCard) a,
  ];

  List<AccountBalance> get cards => [
    for (final a in _all)
      if (a.isCreditCard) a,
  ];

  /// The accounts or the cards, as the tab says.
  List<AccountBalance> get visible => _tab == AccountKind.bank ? banks : cards;

  /// Whether the person (or the house) has no account and no card at all, or
  /// `null` while the list is not known.
  bool? get hasNoConnection => switch (_list) {
    UiSuccess<List<AccountBalance>>() => false,
    UiEmpty<List<AccountBalance>>() => true,
    _ => null,
  };

  /// The person who connected the bank, or `null` if unknown.
  Member? memberOf(String id) {
    final members = profileData?.members ?? const <Member>[];
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// The place of a person in the list of the house, which gives the color.
  int memberIndexOf(String id) {
    final members = profileData?.members ?? const <Member>[];
    final index = members.indexWhere((member) => member.id == id);
    return index < 0 ? 0 : index;
  }

  /// First load of the screen. Waits for the profile, then loads the data.
  Future<void> start() async {
    await _scopeController.ensureLoaded();
    // If the profile failed, the screen shows its error (see `profile`).
    if (profileData == null) {
      _notify();
      return;
    }
    _appliedScope = scope;
    await _loadAll();
  }

  /// Pull to refresh.
  Future<void> reload() async {
    if (profileData == null) return start();
    await _loadAll();
  }

  /// Retries the list after it failed.
  Future<void> retryList() => _loadList(_generation);

  /// Retries the totals after they failed.
  Future<void> retryTotals() => _loadTotals(_generation);

  void selectTab(AccountKind kind) {
    if (kind == _tab) return;
    _tab = kind;
    _notify();
  }

  /// The person chose another option of "who appears" (me, a person, the house).
  Future<void> selectScope(ScopeOption option) async {
    if (profileData == null || option == scope) return;
    _scopeReload = null;
    // The change reaches `_onScopeChanged`, which reloads the data.
    _scopeController.select(option);
    await _scopeReload;
  }

  Future<void> _loadAll() {
    final generation = ++_generation;
    return Future.wait([_loadList(generation), _loadTotals(generation)]);
  }

  Future<void> _loadList(int generation) async {
    _list = const UiLoading();
    _notify();
    final result = await _getBalances(userId: scope?.userId);
    if (_disposed || generation != _generation) return;
    _list = result.when<UiState<List<AccountBalance>>>(
      success: (items) => items.isEmpty ? const UiEmpty() : UiSuccess(items),
      failure: UiError<List<AccountBalance>>.new,
    );
    _notify();
  }

  Future<void> _loadTotals(int generation) async {
    _bankTotal = const UiLoading();
    _cardTotal = const UiLoading();
    _notify();
    final userId = scope?.userId;
    final bank = _getTotal(kind: AccountKind.bank, userId: userId);
    final card = _getTotal(kind: AccountKind.credit, userId: userId);
    final results = (await bank, await card);
    if (_disposed || generation != _generation) return;
    _bankTotal = _toState(results.$1);
    _cardTotal = _toState(results.$2);
    _notify();
  }

  UiState<Decimal> _toState(Result<Decimal> result) =>
      result.when<UiState<Decimal>>(
        success: UiSuccess<Decimal>.new,
        failure: UiError<Decimal>.new,
      );

  /// The profile or the choice of "who appears" changed (here or on another
  /// screen). If the choice changed, the data loads again.
  void _onScopeChanged() {
    final current = scope;
    final changed =
        _appliedScope != null && current != null && current != _appliedScope;
    if (changed) {
      _appliedScope = current;
      _scopeReload = _loadAll();
    } else {
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scopeController.removeListener(_onScopeChanged);
    super.dispose();
  }
}
