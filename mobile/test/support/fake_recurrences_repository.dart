import 'dart:async';

import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/repositories/recurrences_repository.dart';

import 'recurrence_factory.dart';

/// [RecurrencesRepository] over [all] that records every call. Set [failure]
/// to make every call fail, [gate] to hold the provision answer, or
/// [provision] to say what provisioning answers.
class FakeRecurrencesRepository implements RecurrencesRepository {
  List<Recurrence> all = [
    makeRecurrence(),
    makeRecurrence(
      id: 'r2',
      description: 'Salário',
      type: EntryType.revenues,
      paymentType: PaymentType.credit,
      amount: '5000.00',
      dueDay: null,
      category: null,
    ),
  ];

  Failure? failure;
  Result<ProvisionResult> provision = Result.success(
    ProvisionResult(referenceMonth: DateTime(2026, 12), created: 2, skipped: 0),
  );
  Completer<Result<ProvisionResult>>? gate;

  int listCalls = 0;
  int provisionCalls = 0;
  final List<RecurrenceDraft> created = [];
  final List<(String, RecurrenceDraft)> updated = [];
  final List<String> deleted = [];

  Recurrence _from(String id, RecurrenceDraft draft) => Recurrence(
    id: id,
    description: draft.description,
    type: draft.type,
    paymentType: draft.paymentType,
    amount: draft.amount,
    dueDay: draft.dueDay,
    category: draft.category,
    notes: draft.notes,
  );

  @override
  Future<Result<List<Recurrence>>> list() async {
    listCalls++;
    final error = failure;
    if (error != null) return Result.failure(error);
    return Result.success(List.of(all));
  }

  @override
  Future<Result<Recurrence>> create(RecurrenceDraft draft) async {
    final error = failure;
    if (error != null) return Result.failure(error);
    created.add(draft);
    final recurrence = _from('new${created.length}', draft);
    all = [...all, recurrence];
    return Result.success(recurrence);
  }

  @override
  Future<Result<Recurrence>> update(String id, RecurrenceDraft draft) async {
    final error = failure;
    if (error != null) return Result.failure(error);
    updated.add((id, draft));
    final recurrence = _from(id, draft);
    all = [for (final r in all) r.id == id ? recurrence : r];
    return Result.success(recurrence);
  }

  @override
  Future<Result<void>> delete(String id) async {
    final error = failure;
    if (error != null) return Result.failure(error);
    deleted.add(id);
    all = [
      for (final r in all)
        if (r.id != id) r,
    ];
    return const Result.success(null);
  }

  @override
  Future<Result<ProvisionResult>> provisionNextMonth() {
    provisionCalls++;
    final held = gate;
    if (held != null) return held.future;
    return Future.value(provision);
  }
}
