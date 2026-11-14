import 'dart:async';

import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';
import 'package:mobile/features/transactions/domain/repositories/transactions_repository.dart';

import 'transaction_factory.dart';

/// One call to [FakeTransactionsRepository.search].
class SearchCall {
  const SearchCall({
    required this.offset,
    required this.limit,
    required this.userId,
    required this.filters,
    required this.search,
    this.financialEntryId,
  });

  final int offset;
  final int limit;
  final String? userId;
  final TransactionFilters filters;
  final String search;
  final String? financialEntryId;
}

/// [TransactionsRepository] that pages [all], and records every call. Set
/// [forced] to answer something else, or [gate] to hold the answer.
class FakeTransactionsRepository implements TransactionsRepository {
  /// 75 transactions, 6 for each day, newest first (day 12 down to day 1 of
  /// November, then October).
  List<Transaction> all = [
    for (var i = 0; i < 75; i++)
      makeTransaction(
        id: 't$i',
        description: 'Compra $i',
        date: DateTime.utc(2026, 11, 12).subtract(Duration(days: i ~/ 6)),
      ),
  ];

  Result<PageResult<Transaction>>? forced;
  Completer<Result<PageResult<Transaction>>>? gate;
  final List<SearchCall> calls = [];

  @override
  Future<Result<PageResult<Transaction>>> search({
    required int offset,
    required int limit,
    String? userId,
    TransactionFilters filters = const TransactionFilters(),
    String search = '',
    String? financialEntryId,
  }) {
    calls.add(
      SearchCall(
        offset: offset,
        limit: limit,
        userId: userId,
        filters: filters,
        search: search,
        financialEntryId: financialEntryId,
      ),
    );
    final held = gate;
    if (held != null) return held.future;
    final answer = forced;
    if (answer != null) return Future.value(answer);

    final matching = search.trim().isEmpty
        ? all
        : all
              .where(
                (t) => (t.description ?? '').toLowerCase().contains(
                  search.trim().toLowerCase(),
                ),
              )
              .toList();
    final end = (offset + limit).clamp(0, matching.length);
    final items = offset >= matching.length
        ? <Transaction>[]
        : matching.sublist(offset, end);
    return Future.value(
      Result.success(
        PageResult<Transaction>(
          items: items,
          limit: limit,
          offset: offset,
          total: matching.length,
        ),
      ),
    );
  }
}

/// [AccountsRepository] that answers with what the test sets.
class FakeAccountsRepository implements AccountsRepository {
  Result<List<BankAccount>> result = const Result.success([
    BankAccount(
      id: 'a1',
      ownerId: 'm1',
      name: 'Conta Corrente',
      marketingName: 'Nubank',
      number: '0001/12345-6',
      isCreditCard: false,
    ),
    BankAccount(
      id: 'a2',
      ownerId: 'm1',
      name: 'Cartão Platinum',
      marketingName: 'Itaú Card',
      number: '5412 7700 0000 1234',
      isCreditCard: true,
    ),
    BankAccount(
      id: 'a3',
      ownerId: 'm2',
      name: 'Conta Corrente',
      marketingName: 'Inter',
      number: '00099-1',
      isCreditCard: false,
    ),
  ]);
  int calls = 0;

  @override
  Future<Result<List<BankAccount>>> getAccounts() async {
    calls++;
    return result;
  }
}
