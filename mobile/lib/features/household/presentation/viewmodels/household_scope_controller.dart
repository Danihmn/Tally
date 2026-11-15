import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';

/// The logged person and the people of the house.
class HouseholdProfile extends Equatable {
  const HouseholdProfile({required this.me, required this.members});

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

/// The people of the house and the choice of "who appears", shared by every
/// screen: changing it on the home changes it on the transactions too, like in
/// the prototype.
///
/// It is one object for the whole app. The screens listen to it and load their
/// own data again when the choice changes. It forgets everything when the
/// session closes, so the next person to log in starts clean.
class HouseholdScopeController extends ChangeNotifier {
  HouseholdScopeController({
    required this._getMe,
    required this._getMembers,
    required this._session,
  }) {
    _session.addListener(_onSessionChanged);
  }

  final GetMe _getMe;
  final GetHouseholdMembers _getMembers;
  final SessionController _session;

  UiState<HouseholdProfile> _profile = const UiInitial();
  ScopeOption? _selected;

  /// The load that is running, so two screens asking at the same time make one
  /// request.
  Future<void>? _loading;

  /// Grows on every load and on every reset. A load that ends after a reset is
  /// thrown away.
  int _generation = 0;
  bool _disposed = false;

  UiState<HouseholdProfile> get profile => _profile;

  HouseholdProfile? get profileData => switch (_profile) {
    UiSuccess<HouseholdProfile>(:final data) => data,
    _ => null,
  };

  /// The people the person can choose from: "me", the others, and the house.
  List<ScopeOption> get scopeOptions {
    final data = profileData;
    if (data == null) return const [];
    return [
      ScopeOption.me(data.me),
      for (final member in data.members)
        if (member.id != data.me.id) ScopeOption.person(member),
      const ScopeOption.house(),
    ];
  }

  /// The choice in use. At first it is the logged person.
  ScopeOption? get scope {
    final data = profileData;
    if (data == null) return null;
    return _selected ?? ScopeOption.me(data.me);
  }

  /// Loads the profile if it is not loaded yet (or if it failed). It can be
  /// called by many screens: they share the same request.
  Future<void> ensureLoaded() {
    if (_profile is UiSuccess<HouseholdProfile>) return Future.value();
    return _loading ??= _load();
  }

  /// Loads the profile again, for example to see a person that was just added.
  Future<void> reload() => _loading = _load();

  /// Reads the logged person and the people again without going back to the
  /// loading state, so the screens that show them do not flicker. Used after a
  /// person is added or edited. The choice of "who appears" is kept (with the
  /// new data of that person). If the profile is not loaded yet, it loads it.
  /// A failure keeps what was there.
  Future<void> refreshMembers() async {
    final current = profileData;
    if (current == null) return reload();
    final generation = _generation;
    final me = (await _getMe()).valueOrNull ?? current.me;
    final members = (await _getMembers(me)).valueOrNull;
    if (generation != _generation || members == null) return;
    _profile = UiSuccess(HouseholdProfile(me: me, members: members));
    _selected = _refreshedChoice(_selected, me, members);
    _notify();
  }

  /// The same choice, with the up-to-date data of the person it names.
  ScopeOption? _refreshedChoice(
    ScopeOption? choice,
    Member me,
    List<Member> members,
  ) {
    if (choice == null) return null;
    switch (choice.kind) {
      case ScopeKind.house:
        return choice;
      case ScopeKind.me:
        return ScopeOption.me(me);
      case ScopeKind.member:
        for (final member in members) {
          if (member.id == choice.member!.id) return ScopeOption.person(member);
        }
        return ScopeOption.me(me);
    }
  }

  void select(ScopeOption option) {
    if (profileData == null || option == scope) return;
    _selected = option;
    _notify();
  }

  /// Forgets the profile and the choice.
  void reset() {
    _generation++;
    _profile = const UiInitial();
    _selected = null;
    _loading = null;
    _notify();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _profile = const UiLoading();
    _notify();

    final meResult = await _getMe();
    if (generation != _generation) return;
    final me = meResult.valueOrNull;
    if (me == null) {
      _profile = UiError(meResult.failureOrNull!);
      _loading = null;
      _notify();
      return;
    }

    final membersResult = await _getMembers(me);
    if (generation != _generation) return;
    // If the list of people fails, the app still works for the logged person.
    final members = membersResult.valueOrNull ?? [me];
    _profile = UiSuccess(HouseholdProfile(me: me, members: members));
    _selected = ScopeOption.me(me);
    _loading = null;
    _notify();
  }

  void _onSessionChanged() {
    if (!_session.isLoggedIn) reset();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
