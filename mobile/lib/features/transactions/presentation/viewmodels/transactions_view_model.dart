import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/core/pagination/paginated_view_model.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/utils/debouncer.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/accounts/domain/usecases/get_bank_accounts.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_day_group.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';
import 'package:mobile/features/transactions/domain/usecases/search_transactions.dart';

/// State of the transactions list.
///
/// The list is paged by [PaginatedViewModel]. It loads again when the person
/// (shared with the other screens), the search text or the filters change. The
/// accounts load beside it: they give a name to each transaction and say
/// whether the chosen person has connected a bank at all.
class TransactionsViewModel extends ChangeNotifier
    with PaginatedViewModel<Transaction> {
  TransactionsViewModel({
    required this._scopeController,
    required this._searchTransactions,
    required this._getAccounts,
    Debouncer? debouncer,
    this._now = DateTime.now,
  }) : _debouncer = debouncer ?? Debouncer() {
    _scopeController.addListener(_onScopeChanged);
  }

  final HouseholdScopeController _scopeController;
  final SearchTransactions _searchTransactions;
  final GetBankAccounts _getAccounts;
  final Debouncer _debouncer;
  final DateTime Function() _now;

  TransactionFilters _filters = const TransactionFilters();
  String _search = '';
  UiState<List<BankAccount>> _accounts = const UiInitial();
  bool _disposed = false;

  /// The choice that the list on screen was loaded for.
  ScopeOption? _appliedScope;

  /// The reload that the last change of the choice started.
  Future<void>? _scopeReload;

  /// The people of the house and the choice of who appears, shared with the
  /// other screens.
  UiState<HouseholdProfile> get profile => _scopeController.profile;

  HouseholdProfile? get profileData => _scopeController.profileData;

  List<ScopeOption> get scopeOptions => _scopeController.scopeOptions;

  ScopeOption? get scope => _scopeController.scope;

  /// Today, without the time. Gives the "Hoje" and "Ontem" of the list.
  DateTime get today {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  TransactionFilters get filters => _filters;

  /// The text of the search box (what the person typed, even before the list
  /// reacts to it).
  String get search => _search;

  bool get hasSearchOrFilters => _search.trim().isNotEmpty || !_filters.isEmpty;

  UiState<List<BankAccount>> get accounts => _accounts;

  List<BankAccount> get accountList => switch (_accounts) {
    UiSuccess<List<BankAccount>>(:final data) => data,
    _ => const [],
  };

  /// The transactions loaded so far.
  List<Transaction> get items => switch (state) {
    UiSuccess<List<Transaction>>(:final data) => data,
    _ => const [],
  };

  /// The loaded transactions grouped by day.
  List<TransactionDayGroup> get groups => groupTransactionsByDay(items);

  /// Whether the chosen person (or the house) has connected any bank, or
  /// `null` while the accounts are not known.
  bool? get hasConnectedBank {
    final list = switch (_accounts) {
      UiSuccess<List<BankAccount>>(:final data) => data,
      _ => null,
    };
    final current = scope;
    if (list == null || current == null) return null;
    final userId = current.userId;
    return userId == null
        ? list.isNotEmpty
        : list.any((account) => account.ownerId == userId);
  }

  BankAccount? accountOf(String id) {
    for (final account in accountList) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// The person who connected a bank, or `null` if unknown.
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

  /// First load of the screen. Waits for the profile, then loads the accounts
  /// and the first page.
  Future<void> start() async {
    await _scopeController.ensureLoaded();
    // If the profile failed, the screen shows its error (see `profile`).
    if (profileData == null) {
      _notify();
      return;
    }
    _appliedScope = scope;
    unawaited(_loadAccounts());
    await load();
  }

  /// Pull to refresh: the accounts and the list.
  Future<void> reload() async {
    if (profileData == null) return start();
    unawaited(_loadAccounts());
    await refresh();
  }

  /// The person typed in the search box. The list reacts after a short pause.
  void setSearch(String text) {
    if (text == _search) return;
    _search = text;
    _notify();
    _debouncer.run(() => unawaited(load()));
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    _debouncer.cancel();
    _search = '';
    unawaited(load());
  }

  /// The person chose another option of "who appears" (me, a person, the house).
  Future<void> selectScope(ScopeOption option) async {
    if (profileData == null || option == scope) return;
    _scopeReload = null;
    // The change reaches `_onScopeChanged`, which reloads the list.
    _scopeController.select(option);
    await _scopeReload;
  }

  /// Applies the filters of the sheet and, if the person changed there, the
  /// new choice of who appears.
  Future<void> applyFilters(
    TransactionFilters filters, {
    ScopeOption? scope,
  }) async {
    _debouncer.cancel();
    _filters = filters;
    _scopeReload = null;
    if (scope != null && scope != this.scope) {
      // The change reaches `_onScopeChanged`, which reloads the list.
      _scopeController.select(scope);
      await _scopeReload;
    } else {
      await load();
    }
  }

  /// A chip of the list was removed.
  Future<void> removeFilter(TransactionFilterKey key) async {
    _debouncer.cancel();
    _filters = _filters.without(key);
    await load();
  }

  /// "Clear search and filters".
  Future<void> clearAll() async {
    _debouncer.cancel();
    _search = '';
    _filters = const TransactionFilters();
    await load();
  }

  /// Retries the accounts after they failed.
  Future<void> retryAccounts() => _loadAccounts();

  @override
  Future<Result<PageResult<Transaction>>> fetchPage({
    required int offset,
    required int limit,
  }) => _searchTransactions(
    offset: offset,
    limit: limit,
    userId: scope?.userId,
    filters: _filters,
    search: _search,
  );

  Future<void> _loadAccounts() async {
    _accounts = const UiLoading();
    _notify();
    final result = await _getAccounts();
    if (_disposed) return;
    _accounts = result.when<UiState<List<BankAccount>>>(
      success: UiSuccess<List<BankAccount>>.new,
      failure: UiError<List<BankAccount>>.new,
    );
    _notify();
  }

  /// The profile or the choice of "who appears" changed (here or on another
  /// screen). If the choice changed, the list loads again.
  void _onScopeChanged() {
    final current = scope;
    final changed =
        _appliedScope != null && current != null && current != _appliedScope;
    if (changed) {
      _appliedScope = current;
      _scopeReload = load();
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
    _debouncer.dispose();
    super.dispose();
  }
}
