import 'package:flutter/foundation.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/create_recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/delete_recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/list_recurrences.dart';
import 'package:mobile/features/recurrences/domain/usecases/provision_next_month.dart';
import 'package:mobile/features/recurrences/domain/usecases/set_recurrence_status.dart';
import 'package:mobile/features/recurrences/domain/usecases/update_recurrence.dart';

/// State of the recurrences list (one tab: active or cancelled) and of its
/// changes (create, edit, cancel, reactivate, delete and provision next
/// month). After a change the list is read again.
///
/// The people of the house come from [HouseholdScopeController]: the form
/// picks the owner among them.
class RecurrencesViewModel extends ChangeNotifier {
  RecurrencesViewModel({
    required ListRecurrences listRecurrences,
    required CreateRecurrence createRecurrence,
    required UpdateRecurrence updateRecurrence,
    required SetRecurrenceStatus setRecurrenceStatus,
    required DeleteRecurrence deleteRecurrence,
    required ProvisionNextMonth provisionNextMonth,
    required HouseholdScopeController scopeController,
    this._now = DateTime.now,
  }) : _list = listRecurrences,
       _create = createRecurrence,
       _update = updateRecurrence,
       _setStatus = setRecurrenceStatus,
       _delete = deleteRecurrence,
       _provision = provisionNextMonth,
       _scope = scopeController {
    _scope.addListener(_notify);
  }

  final ListRecurrences _list;
  final CreateRecurrence _create;
  final UpdateRecurrence _update;
  final SetRecurrenceStatus _setStatus;
  final DeleteRecurrence _delete;
  final ProvisionNextMonth _provision;
  final HouseholdScopeController _scope;
  final DateTime Function() _now;

  UiState<List<Recurrence>> _state = const UiInitial();
  RecurrenceStatus _tab = RecurrenceStatus.active;
  bool _isProvisioning = false;
  bool _disposed = false;

  UiState<List<Recurrence>> get state => _state;

  /// The tab on screen: the active recurrences or the cancelled ones.
  RecurrenceStatus get tab => _tab;

  /// Whether the request to provision the next month is running.
  bool get isProvisioning => _isProvisioning;

  /// Everybody of the house, the logged person first.
  List<Member> get members => _scope.profileData?.members ?? const [];

  /// The logged person, the default owner of a new recurrence.
  Member? get me => _scope.profileData?.me;

  /// The person with [id], or `null` when unknown.
  Member? memberOf(String? id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// The first day of the month that "provision" creates the entries for.
  DateTime get nextMonth {
    final now = _now();
    return DateTime(now.year, now.month + 1);
  }

  /// First load: shows the skeleton.
  Future<void> load() async {
    _state = const UiLoading();
    _notify();
    await Future.wait([_scope.ensureLoaded(), _fetch()]);
  }

  /// Pull to refresh or retry: keeps what is on screen while it loads.
  Future<void> reload() => _fetch();

  /// Shows the active or the cancelled recurrences.
  Future<void> selectTab(RecurrenceStatus status) async {
    if (status == _tab) return;
    _tab = status;
    await load();
  }

  /// Creates a recurrence. Returns `null` when it worked, otherwise why not.
  Future<Failure?> create(RecurrenceDraft draft) async =>
      _changed(await _create(draft));

  /// Replaces the data of a recurrence.
  Future<Failure?> update(String id, RecurrenceDraft draft) async =>
      _changed(await _update(id, draft));

  /// Cancels a recurrence (it leaves this tab) or reactivates it.
  Future<Failure?> setStatus(String id, RecurrenceStatus status) async =>
      _changed(await _setStatus(id, status));

  /// Deletes a recurrence. The entries it created stay.
  Future<Failure?> delete(String id) async => _changed(await _delete(id));

  /// Creates next month's entries from the active recurrences. The list does
  /// not change, so it is not read again.
  Future<Result<ProvisionResult>> provisionNextMonth() async {
    if (_isProvisioning) {
      return const Result.failure(UnknownFailure());
    }
    _isProvisioning = true;
    _notify();
    final result = await _provision();
    _isProvisioning = false;
    _notify();
    return result;
  }

  Future<Failure?> _changed(Result<Object?> result) async {
    final failure = result.failureOrNull;
    if (failure != null) return failure;
    await _fetch();
    return null;
  }

  Future<void> _fetch() async {
    final tab = _tab;
    final result = await _list(tab);
    // The tab changed while it loaded: that tab loads its own list.
    if (_disposed || tab != _tab) return;
    final previous = _state;
    _state = result.when<UiState<List<Recurrence>>>(
      success: (items) => items.isEmpty ? const UiEmpty() : UiSuccess(items),
      // A refresh that fails keeps the list that is already on screen.
      failure: (failure) =>
          previous is UiSuccess<List<Recurrence>> ? previous : UiError(failure),
    );
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scope.removeListener(_notify);
    super.dispose();
  }
}
