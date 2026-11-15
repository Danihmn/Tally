import 'package:flutter/foundation.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/create_recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/delete_recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/list_recurrences.dart';
import 'package:mobile/features/recurrences/domain/usecases/provision_next_month.dart';
import 'package:mobile/features/recurrences/domain/usecases/update_recurrence.dart';

/// State of the recurrences list and of its changes (create, edit, delete and
/// provision next month). After a change the list is read again.
class RecurrencesViewModel extends ChangeNotifier {
  RecurrencesViewModel({
    required ListRecurrences listRecurrences,
    required CreateRecurrence createRecurrence,
    required UpdateRecurrence updateRecurrence,
    required DeleteRecurrence deleteRecurrence,
    required ProvisionNextMonth provisionNextMonth,
    this._now = DateTime.now,
  }) : _list = listRecurrences,
       _create = createRecurrence,
       _update = updateRecurrence,
       _delete = deleteRecurrence,
       _provision = provisionNextMonth;

  final ListRecurrences _list;
  final CreateRecurrence _create;
  final UpdateRecurrence _update;
  final DeleteRecurrence _delete;
  final ProvisionNextMonth _provision;
  final DateTime Function() _now;

  UiState<List<Recurrence>> _state = const UiInitial();
  bool _isProvisioning = false;
  bool _disposed = false;

  UiState<List<Recurrence>> get state => _state;

  /// Whether the request to provision the next month is running.
  bool get isProvisioning => _isProvisioning;

  /// The first day of the month that "provision" creates the entries for.
  DateTime get nextMonth {
    final now = _now();
    return DateTime(now.year, now.month + 1);
  }

  /// First load: shows the skeleton.
  Future<void> load() async {
    _state = const UiLoading();
    _notify();
    await _fetch();
  }

  /// Pull to refresh or retry: keeps what is on screen while it loads.
  Future<void> reload() => _fetch();

  /// Creates a recurrence. Returns `null` when it worked, otherwise why not.
  Future<Failure?> create(RecurrenceDraft draft) async =>
      _changed(await _create(draft));

  /// Replaces the data of a recurrence.
  Future<Failure?> update(String id, RecurrenceDraft draft) async =>
      _changed(await _update(id, draft));

  /// Deletes a recurrence. The entries it created stay.
  Future<Failure?> delete(String id) async => _changed(await _delete(id));

  /// Creates next month's entries from the recurrences. The list does not
  /// change, so it is not read again.
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
    final result = await _list();
    if (_disposed) return;
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
    super.dispose();
  }
}
