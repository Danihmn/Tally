import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/pagination/paginated_view_model.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/utils/debouncer.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/accounts/domain/usecases/get_bank_accounts.dart';
import 'package:mobile/features/entries/domain/entities/entry_draft.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/usecases/create_entry.dart';
import 'package:mobile/features/entries/domain/usecases/search_entries.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

/// State of the entries list.
///
/// The list is paged by [PaginatedViewModel]. It shows one tab (status) of one
/// month (or every month) for the chosen person (shared with the other
/// screens), and loads again when any of them, the search text or the filters
/// change. The accounts load beside it and give a name to each entry. The
/// number on each tab is counted with the same month, person, search and
/// filters, so it does not change when the tab changes.
class EntriesViewModel extends ChangeNotifier
    with PaginatedViewModel<FinancialEntry> {
  EntriesViewModel({
    required this._scopeController,
    required this._searchEntries,
    required this._getAccounts,
    required this._createEntry,
    Debouncer? debouncer,
    this._now = DateTime.now,
  }) : _debouncer = debouncer ?? Debouncer() {
    _scopeController.addListener(_onScopeChanged);
    _month = DateTime(_now().year, _now().month);
  }

  /// Months before the current one that have a chip.
  static const monthsBefore = 3;

  final HouseholdScopeController _scopeController;
  final SearchEntries _searchEntries;
  final GetBankAccounts _getAccounts;
  final CreateEntry _createEntry;
  final Debouncer _debouncer;
  final DateTime Function() _now;

  EntryStatus _tab = EntryStatus.planned;
  DateTime? _month;
  EntryFilters _filters = const EntryFilters();
  String _search = '';
  UiState<List<BankAccount>> _accounts = const UiInitial();
  final Map<EntryStatus, int> _counts = {};
  int _countsGeneration = 0;
  bool _disposed = false;

  /// The choice that the list on screen was loaded for.
  ScopeOption? _appliedScope;

  /// The reload that the last change of the choice started.
  Future<void>? _scopeReload;

  UiState<HouseholdProfile> get profile => _scopeController.profile;

  HouseholdProfile? get profileData => _scopeController.profileData;

  List<ScopeOption> get scopeOptions => _scopeController.scopeOptions;

  ScopeOption? get scope => _scopeController.scope;

  /// Today, without the time. Tells which entries are overdue.
  DateTime get today {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  EntryStatus get tab => _tab;

  /// The month on screen (its first day), or `null` for every month.
  DateTime? get month => _month;

  /// The months with a chip, in order: the last [monthsBefore], the current
  /// one and the next. `null` (the "Todos" chip) is not in the list.
  List<DateTime> get months {
    final now = _now();
    return [
      for (var i = -monthsBefore; i <= 1; i++)
        DateTime(now.year, now.month + i),
    ];
  }

  EntryFilters get filters => _filters;

  /// The text of the search box (what the person typed, even before the list
  /// reacts to it).
  String get search => _search;

  bool get hasSearchOrFilters => _search.trim().isNotEmpty || !_filters.isEmpty;

  UiState<List<BankAccount>> get accounts => _accounts;

  List<BankAccount> get accountList => switch (_accounts) {
    UiSuccess<List<BankAccount>>(:final data) => data,
    _ => const [],
  };

  /// The entries loaded so far.
  List<FinancialEntry> get items => switch (state) {
    UiSuccess<List<FinancialEntry>>(:final data) => data,
    _ => const [],
  };

  /// How many entries each tab has, or `null` while it is not known.
  int? countOf(EntryStatus status) => _counts[status];

  BankAccount? accountOf(String? id) {
    if (id == null) return null;
    for (final account in accountList) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// The person the entry belongs to, or `null` if unknown.
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

  /// First load of the screen. Waits for the profile, then loads the accounts,
  /// the counts and the first page.
  Future<void> start() async {
    await _scopeController.ensureLoaded();
    // If the profile failed, the screen shows its error (see `profile`).
    if (profileData == null) {
      _notify();
      return;
    }
    _appliedScope = scope;
    unawaited(_loadAccounts());
    unawaited(_loadCounts());
    await load();
  }

  /// Pull to refresh: the accounts, the counts and the list.
  Future<void> reload() async {
    if (profileData == null) return start();
    unawaited(_loadAccounts());
    unawaited(_loadCounts());
    await refresh();
  }

  /// Chooses the month the list opens on, before the first load (for example
  /// right after the next month was provisioned). `null` is "Todos".
  void presetMonth(DateTime? month) {
    _month = month == null ? null : DateTime(month.year, month.month);
  }

  /// Creates an entry for the logged person and reads the list again. Returns
  /// `null` when it worked, otherwise why it did not.
  Future<Failure?> create(EntryDraft draft) async {
    final failure = (await _createEntry(draft)).failureOrNull;
    if (failure != null) return failure;
    if (!_disposed) await reload();
    return null;
  }

  /// A tab was chosen. The counts do not change.
  Future<void> selectTab(EntryStatus status) async {
    if (status == _tab) return;
    _tab = status;
    await load();
  }

  /// A month chip was chosen (`null` is "Todos").
  Future<void> selectMonth(DateTime? month) async {
    final value = month == null ? null : DateTime(month.year, month.month);
    if (value == _month) return;
    _month = value;
    await _reloadAll();
  }

  /// The person typed in the search box. The list reacts after a short pause.
  void setSearch(String text) {
    if (text == _search) return;
    _search = text;
    _notify();
    _debouncer.run(() => unawaited(_reloadAll()));
  }

  void clearSearch() {
    if (_search.isEmpty) return;
    _debouncer.cancel();
    _search = '';
    unawaited(_reloadAll());
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
  Future<void> applyFilters(EntryFilters filters, {ScopeOption? scope}) async {
    _debouncer.cancel();
    _filters = filters;
    _scopeReload = null;
    if (scope != null && scope != this.scope) {
      // The change reaches `_onScopeChanged`, which reloads the list.
      _scopeController.select(scope);
      await _scopeReload;
    } else {
      await _reloadAll();
    }
  }

  /// A chip of the list was removed.
  Future<void> removeFilter(EntryFilterKey key) async {
    _debouncer.cancel();
    _filters = _filters.without(key);
    await _reloadAll();
  }

  /// "Clear search and filters". The tab and the month stay.
  Future<void> clearAll() async {
    _debouncer.cancel();
    _search = '';
    _filters = const EntryFilters();
    await _reloadAll();
  }

  /// Retries the accounts after they failed.
  Future<void> retryAccounts() => _loadAccounts();

  @override
  Future<Result<PageResult<FinancialEntry>>> fetchPage({
    required int offset,
    required int limit,
  }) => _query(status: _tab, offset: offset, limit: limit);

  Future<Result<PageResult<FinancialEntry>>> _query({
    required EntryStatus status,
    required int offset,
    required int limit,
  }) => _searchEntries(
    offset: offset,
    limit: limit,
    userId: scope?.userId,
    status: status,
    referenceMonth: _month,
    filters: _filters,
    search: _search,
  );

  Future<void> _reloadAll() {
    unawaited(_loadCounts());
    return load();
  }

  /// Counts every tab with a page of one item: only the `total` is used.
  Future<void> _loadCounts() async {
    final generation = ++_countsGeneration;
    _counts.clear();
    _notify();
    await Future.wait([
      for (final status in EntryStatus.values)
        _query(status: status, offset: 0, limit: 1).then((result) {
          if (_disposed || generation != _countsGeneration) return;
          final total = result.valueOrNull?.total;
          if (total != null) _counts[status] = total;
          _notify();
        }),
    ]);
  }

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
      _scopeReload = _reloadAll();
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
