import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/auth/domain/usecases/logout.dart';
import 'package:mobile/features/home/domain/entities/daily_amount.dart';
import 'package:mobile/features/home/domain/entities/month_period.dart';
import 'package:mobile/features/home/domain/entities/planning_progress.dart';
import 'package:mobile/features/home/domain/entities/spending_by_member.dart';
import 'package:mobile/features/home/domain/entities/spending_summary.dart';
import 'package:mobile/features/home/domain/entities/top_expense.dart';
import 'package:mobile/features/home/domain/entities/upcoming_entry.dart';
import 'package:mobile/features/home/domain/usecases/get_daily_spending.dart';
import 'package:mobile/features/home/domain/usecases/get_planning_progress.dart';
import 'package:mobile/features/home/domain/usecases/get_spending_by_member.dart';
import 'package:mobile/features/home/domain/usecases/get_spending_summary.dart';
import 'package:mobile/features/home/domain/usecases/get_top_expenses.dart';
import 'package:mobile/features/home/domain/usecases/get_upcoming_entries.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';

/// The logged person and the people of the house.
class HomeProfile extends Equatable {
  const HomeProfile({required this.me, required this.members});

  final Member me;

  /// Everybody of the house, [me] first.
  final List<Member> members;

  @override
  List<Object?> get props => [me, members];
}

enum ScopeKind { me, member, house }

/// One choice of "who appears": the logged person, another person, or the
/// whole house.
class ScopeOption extends Equatable {
  const ScopeOption.me(Member this.member) : kind = ScopeKind.me;

  const ScopeOption.person(Member this.member) : kind = ScopeKind.member;

  const ScopeOption.house() : kind = ScopeKind.house, member = null;

  final ScopeKind kind;

  /// The person, or `null` for the whole house.
  final Member? member;

  /// What goes in the `user_id` query parameter. `null` means the whole house.
  String? get userId => member?.id;

  @override
  List<Object?> get props => [kind, member];
}

/// The parts of the home that load and fail on their own.
enum HomeSection { summary, planning, byMember, daily, topExpenses, upcoming }

/// State of the home screen.
///
/// The profile (who is logged, who is in the house) loads first. Then every
/// section loads by itself and at the same time, with its own state: one that
/// fails shows its own error and the others keep working.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this._getMe,
    required this._getMembers,
    required this._getSummary,
    required this._getPlanning,
    required this._getByMember,
    required this._getDaily,
    required this._getTopExpenses,
    required this._getUpcoming,
    required this._logout,
    required this._session,
    this._now = DateTime.now,
  }) {
    _period = MonthPeriod.containing(today);
  }

  final GetMe _getMe;
  final GetHouseholdMembers _getMembers;
  final GetSpendingSummary _getSummary;
  final GetPlanningProgress _getPlanning;
  final GetSpendingByMember _getByMember;
  final GetDailySpending _getDaily;
  final GetTopExpenses _getTopExpenses;
  final GetUpcomingEntries _getUpcoming;
  final Logout _logout;
  final SessionController _session;
  final DateTime Function() _now;

  late MonthPeriod _period;
  ScopeOption? _scope;
  bool _disposed = false;

  /// Grows on every new load. An answer that comes back for an older load (for
  /// example the previous month) is thrown away.
  int _generation = 0;

  UiState<HomeProfile> _profile = const UiInitial();
  UiState<SpendingSummary> _summary = const UiInitial();
  UiState<PlanningProgress> _planning = const UiInitial();
  UiState<SpendingByMember> _byMember = const UiInitial();
  UiState<List<DailyAmount>> _daily = const UiInitial();
  UiState<List<TopExpense>> _topExpenses = const UiInitial();
  UiState<List<UpcomingEntry>> _upcoming = const UiInitial();

  UiState<HomeProfile> get profile => _profile;
  UiState<SpendingSummary> get summary => _summary;
  UiState<PlanningProgress> get planning => _planning;
  UiState<SpendingByMember> get byMember => _byMember;
  UiState<List<DailyAmount>> get daily => _daily;
  UiState<List<TopExpense>> get topExpenses => _topExpenses;
  UiState<List<UpcomingEntry>> get upcoming => _upcoming;

  MonthPeriod get period => _period;

  /// Today, without the time.
  DateTime get today {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  HomeProfile? get _profileData => switch (_profile) {
    UiSuccess<HomeProfile>(:final data) => data,
    _ => null,
  };

  /// The people the person can choose from: "me", the others, and the house.
  List<ScopeOption> get scopeOptions {
    final profile = _profileData;
    if (profile == null) return const [];
    return [
      ScopeOption.me(profile.me),
      for (final member in profile.members)
        if (member.id != profile.me.id) ScopeOption.person(member),
      const ScopeOption.house(),
    ];
  }

  /// The choice in use. At first it is the logged person.
  ScopeOption? get scope {
    final profile = _profileData;
    if (profile == null) return null;
    return _scope ?? ScopeOption.me(profile.me);
  }

  bool get canGoPrevious => _period.canGoPrevious(today);

  bool get canGoNext => _period.canGoNext(today);

  /// The last day with numbers (yesterday for the current month), or `null`
  /// when no day is over yet.
  DateTime? get lastClosedDay => _period.spendingRange(today)?.to;

  /// The card "spent by person" only makes sense for the whole house, with
  /// more than one person.
  bool get showsByMember {
    final profile = _profileData;
    return profile != null &&
        scope?.kind == ScopeKind.house &&
        profile.members.length > 1;
  }

  /// There is spending in the period, so the details (by day, biggest
  /// expenses, by person) have something to show.
  bool get hasSpending => switch (_summary) {
    UiSuccess<SpendingSummary>(:final data) => data.hasSpending,
    _ => false,
  };

  /// A section that failed for lack of connection, or `null`. The screen
  /// shows the offline strip when there is one.
  Failure? get networkFailure {
    final states = <UiState<Object?>>[
      _summary,
      _planning,
      _byMember,
      _daily,
      _topExpenses,
      _upcoming,
    ];
    for (final state in states) {
      if (state case UiError<Object?>(:final failure)) {
        if (failure is NetworkFailure) return failure;
      }
    }
    return null;
  }

  /// First load. Also what "try again" does when the profile failed.
  Future<void> load() async {
    final generation = ++_generation;
    _profile = const UiLoading();
    _setSectionsLoading();
    _notify();

    final meResult = await _getMe();
    if (generation != _generation) return;
    final me = meResult.valueOrNull;
    if (me == null) {
      _profile = UiError(meResult.failureOrNull!);
      _notify();
      return;
    }

    final membersResult = await _getMembers(me);
    if (generation != _generation) return;
    // If the list of people fails, the home still works for the logged person.
    final members = membersResult.valueOrNull ?? [me];
    _profile = UiSuccess(HomeProfile(me: me, members: members));
    _scope = ScopeOption.me(me);
    await _loadSections(showLoading: true);
  }

  /// Loads everything again. The numbers on screen stay until the new ones
  /// arrive (pull to refresh).
  Future<void> refresh() async {
    if (_profileData == null) return load();
    await _loadSections(showLoading: false);
  }

  Future<void> selectScope(ScopeOption option) async {
    if (_profileData == null || option == scope) return;
    _scope = option;
    await _loadSections(showLoading: true);
  }

  Future<void> goToPreviousMonth() async {
    if (_profileData == null || !canGoPrevious) return;
    _period = _period.previous;
    await _loadSections(showLoading: true);
  }

  Future<void> goToNextMonth() async {
    if (_profileData == null || !canGoNext) return;
    _period = _period.next;
    await _loadSections(showLoading: true);
  }

  /// Tries one section again, after it failed.
  Future<void> retry(HomeSection section) async {
    switch (section) {
      case HomeSection.summary:
        _summary = const UiLoading();
      case HomeSection.planning:
        _planning = const UiLoading();
      case HomeSection.byMember:
        _byMember = const UiLoading();
      case HomeSection.daily:
        _daily = const UiLoading();
      case HomeSection.topExpenses:
        _topExpenses = const UiLoading();
      case HomeSection.upcoming:
        _upcoming = const UiLoading();
    }
    _notify();
    await _loadSection(section);
  }

  /// Ends the session. The router then goes to the login screen.
  Future<void> logout() async {
    await _logout();
    _session.onLoggedOut();
  }

  void _setSectionsLoading() {
    _summary = const UiLoading();
    _planning = const UiLoading();
    _byMember = const UiLoading();
    _daily = const UiLoading();
    _topExpenses = const UiLoading();
    _upcoming = const UiLoading();
  }

  Future<void> _loadSections({required bool showLoading}) {
    _generation++;
    if (showLoading) _setSectionsLoading();
    _notify();
    return Future.wait([
      for (final section in HomeSection.values) _loadSection(section),
    ]);
  }

  Future<void> _loadSection(HomeSection section) => switch (section) {
    HomeSection.summary => _loadSummary(),
    HomeSection.planning => _loadPlanning(),
    HomeSection.byMember => _loadByMember(),
    HomeSection.daily => _loadDaily(),
    HomeSection.topExpenses => _loadTopExpenses(),
    HomeSection.upcoming => _loadUpcoming(),
  };

  Future<void> _loadSummary() async {
    final generation = _generation;
    final range = _period.spendingRange(today);
    if (range == null) {
      // No day is over yet: there is nothing to ask the API.
      _summary = UiSuccess(SpendingSummary.zero());
      _notify();
      return;
    }
    final result = await _getSummary(range, userId: scope?.userId);
    if (generation != _generation) return;
    _summary = _stateOf(result);
    _notify();
  }

  Future<void> _loadPlanning() async {
    final generation = _generation;
    final result = await _getPlanning(
      _period.wholeMonth,
      userId: scope?.userId,
    );
    if (generation != _generation) return;
    _planning = _stateOf(result);
    _notify();
  }

  Future<void> _loadByMember() async {
    final generation = _generation;
    final range = _period.spendingRange(today);
    final profile = _profileData;
    if (range == null || profile == null || !showsByMember) {
      _byMember = const UiEmpty();
      _notify();
      return;
    }
    final result = await _getByMember(range, profile.members);
    if (generation != _generation) return;
    _byMember = _stateOf(result);
    _notify();
  }

  Future<void> _loadDaily() async {
    final generation = _generation;
    final range = _period.spendingRange(today);
    if (range == null) {
      _daily = const UiEmpty();
      _notify();
      return;
    }
    final result = await _getDaily(range, userId: scope?.userId);
    if (generation != _generation) return;
    _daily = _stateOf(result);
    _notify();
  }

  Future<void> _loadTopExpenses() async {
    final generation = _generation;
    final range = _period.spendingRange(today);
    if (range == null) {
      _topExpenses = const UiEmpty();
      _notify();
      return;
    }
    final result = await _getTopExpenses(range, userId: scope?.userId);
    if (generation != _generation) return;
    _topExpenses = _stateOf(result);
    _notify();
  }

  Future<void> _loadUpcoming() async {
    final generation = _generation;
    final result = await _getUpcoming(userId: scope?.userId);
    if (generation != _generation) return;
    _upcoming = _stateOf(result);
    _notify();
  }

  UiState<T> _stateOf<T>(Result<T> result) => result.when<UiState<T>>(
    success: UiSuccess<T>.new,
    failure: UiError<T>.new,
  );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
