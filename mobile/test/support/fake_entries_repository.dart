import 'dart:async';

import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/repositories/entries_repository.dart';

import 'entry_factory.dart';

/// One call to [FakeEntriesRepository.search].
class EntrySearchCall {
  const EntrySearchCall({
    required this.offset,
    required this.limit,
    required this.userId,
    required this.status,
    required this.referenceMonth,
    required this.filters,
    required this.search,
    required this.transactionId,
  });

  final int offset;
  final int limit;
  final String? userId;
  final EntryStatus? status;
  final DateTime? referenceMonth;
  final EntryFilters filters;
  final String search;
  final String? transactionId;
}

/// [EntriesRepository] over [all] that filters by owner, status, month and
/// search text, and records every call. Set [forced] to answer something else,
/// [gate] to hold the answer, or [byTransaction] to say which entries a
/// transaction is matched with.
class FakeEntriesRepository implements EntriesRepository {
  /// Today is 13 November 2026 in the tests that use this list.
  List<FinancialEntry> all = [
    makeEntry(
      id: 'e1',
      description: 'Aluguel',
      dueDate: DateTime(2026, 11, 20),
    ),
    makeEntry(
      id: 'e2',
      description: 'Internet',
      amount: '120.00',
      dueDate: DateTime(2026, 11, 10),
    ),
    makeEntry(
      id: 'e3',
      description: 'Salário',
      type: EntryType.revenues,
      paymentType: PaymentType.credit,
      amount: '5000.00',
      dueDate: DateTime(2026, 11, 5),
      installmentNumber: 2,
      installmentTotal: 5,
    ),
    makeEntry(
      id: 'e4',
      description: 'Luz',
      amount: '180.00',
      status: EntryStatus.reconciled,
    ),
    makeEntry(
      id: 'e5',
      description: 'Academia',
      amount: '99.90',
      status: EntryStatus.cancelled,
    ),
    makeEntry(
      id: 'e6',
      description: 'Seguro',
      ownerId: 'm2',
      referenceMonth: DateTime(2026, 10),
      dueDate: DateTime(2026, 10, 28),
    ),
  ];

  /// Entries matched with a transaction, by the id of the transaction.
  Map<String, List<FinancialEntry>> byTransaction = {};

  Result<PageResult<FinancialEntry>>? forced;
  Completer<Result<PageResult<FinancialEntry>>>? gate;
  final List<EntrySearchCall> calls = [];

  @override
  Future<Result<PageResult<FinancialEntry>>> search({
    required int offset,
    required int limit,
    String? userId,
    EntryStatus? status,
    DateTime? referenceMonth,
    EntryFilters filters = const EntryFilters(),
    String search = '',
    String? transactionId,
  }) {
    calls.add(
      EntrySearchCall(
        offset: offset,
        limit: limit,
        userId: userId,
        status: status,
        referenceMonth: referenceMonth,
        filters: filters,
        search: search,
        transactionId: transactionId,
      ),
    );
    final held = gate;
    if (held != null) return held.future;
    final answer = forced;
    if (answer != null) return Future.value(answer);

    final text = search.trim().toLowerCase();
    final source = transactionId == null
        ? all
        : (byTransaction[transactionId] ?? const <FinancialEntry>[]);
    final matching = source.where((entry) {
      if (userId != null && entry.ownerId != userId) return false;
      if (status != null && entry.status != status) return false;
      if (referenceMonth != null &&
          (entry.referenceMonth.year != referenceMonth.year ||
              entry.referenceMonth.month != referenceMonth.month)) {
        return false;
      }
      if (text.isNotEmpty && !entry.description.toLowerCase().contains(text)) {
        return false;
      }
      return true;
    }).toList();
    final end = (offset + limit).clamp(0, matching.length);
    final items = offset >= matching.length
        ? <FinancialEntry>[]
        : matching.sublist(offset, end);
    return Future.value(
      Result.success(
        PageResult<FinancialEntry>(
          items: items,
          limit: limit,
          offset: offset,
          total: matching.length,
        ),
      ),
    );
  }
}
