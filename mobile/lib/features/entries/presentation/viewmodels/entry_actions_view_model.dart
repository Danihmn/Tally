import 'package:flutter/foundation.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/domain/entities/entry_draft.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/usecases/delete_entry.dart';
import 'package:mobile/features/entries/domain/usecases/set_entry_status.dart';
import 'package:mobile/features/entries/domain/usecases/update_entry.dart';

/// The changes the entry detail offers: edit, cancel, reopen and delete. Each
/// returns `null` when it worked, otherwise why it did not. [isBusy] is true
/// while one is running, so the buttons wait.
class EntryActionsViewModel extends ChangeNotifier {
  EntryActionsViewModel({
    required UpdateEntry updateEntry,
    required SetEntryStatus setEntryStatus,
    required DeleteEntry deleteEntry,
  }) : _update = updateEntry,
       _setStatus = setEntryStatus,
       _delete = deleteEntry;

  final UpdateEntry _update;
  final SetEntryStatus _setStatus;
  final DeleteEntry _delete;

  bool _isBusy = false;
  bool _disposed = false;

  bool get isBusy => _isBusy;

  Future<Failure?> update(String id, EntryDraft draft) =>
      _run(() => _update(id, draft));

  Future<Failure?> cancel(String id) =>
      _run(() => _setStatus(id, EntryStatus.cancelled));

  Future<Failure?> reopen(String id) =>
      _run(() => _setStatus(id, EntryStatus.planned));

  Future<Failure?> delete(String id) => _run(() => _delete(id));

  Future<Failure?> _run(Future<Result<Object?>> Function() action) async {
    if (_isBusy) return const UnknownFailure();
    _isBusy = true;
    _notify();
    final result = await action();
    _isBusy = false;
    _notify();
    return result.failureOrNull;
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
