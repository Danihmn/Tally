import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/accounts/domain/entities/card_bill.dart';
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

  /// What `linkEntry` and `unlinkEntry` answer, and what they got.
  Result<void> linkResult = const Result<void>.success(null);
  final List<(String, String)> linked = [];
  final List<(String, String)> unlinked = [];

  @override
  Future<Result<void>> linkEntry(String transactionId, String entryId) async {
    linked.add((transactionId, entryId));
    return linkResult;
  }

  @override
  Future<Result<void>> unlinkEntry(String transactionId, String entryId) async {
    unlinked.add((transactionId, entryId));
    return linkResult;
  }

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

  /// Accounts and cards with a balance. The two accounts and the two cards
  /// belong to `m1` (Ana) and `m2` (Bia), one each.
  List<AccountBalance> balances = [
    AccountBalance(
      id: 'a1',
      ownerId: 'm1',
      kind: AccountKind.bank,
      name: 'Conta Corrente',
      marketingName: 'Nubank',
      number: '0001/12345-6',
      balance: Decimal.parse('2301.45'),
      credit: null,
    ),
    AccountBalance(
      id: 'a3',
      ownerId: 'm2',
      kind: AccountKind.bank,
      name: 'Conta Corrente',
      marketingName: 'Inter',
      number: '00099-1',
      balance: Decimal.parse('1200.00'),
      credit: null,
    ),
    AccountBalance(
      id: 'a2',
      ownerId: 'm1',
      kind: AccountKind.credit,
      name: 'Cartão Platinum',
      marketingName: 'Itaú Card',
      number: '5412 7700 0000 1234',
      balance: Decimal.parse('1500.00'),
      credit: CreditInfo(
        creditLimit: Decimal.parse('5000.00'),
        availableCreditLimit: Decimal.parse('3500.00'),
        dueDate: DateTime.utc(2026, 11, 17),
        closeDate: DateTime.utc(2026, 11, 8),
      ),
      // The bill due next month: one installment of each purchase.
      nextBill: CardBillSummary(
        month: DateTime(2026, 12),
        total: Decimal.parse('150.00'),
        estimated: false,
      ),
    ),
    AccountBalance(
      id: 'a4',
      ownerId: 'm2',
      kind: AccountKind.credit,
      name: 'Cartão Nu',
      marketingName: 'Nubank',
      number: '9876',
      balance: Decimal.parse('300.00'),
      credit: null,
    ),
  ];

  Result<List<AccountBalance>>? balancesForced;
  Result<Decimal>? totalForced;
  final List<String?> balanceCalls = [];
  final List<(AccountKind, String?)> totalCalls = [];

  @override
  Future<Result<List<AccountBalance>>> getBalances({String? userId}) async {
    balanceCalls.add(userId);
    return balancesForced ??
        Result.success([
          for (final b in balances)
            if (userId == null || b.ownerId == userId) b,
        ]);
  }

  @override
  Future<Result<Decimal>> getTotalBalance({
    required AccountKind kind,
    String? userId,
  }) async {
    totalCalls.add((kind, userId));
    final forced = totalForced;
    if (forced != null) return forced;
    // Like the server: the accounts sum their balances, the cards sum the
    // bills due next month.
    var sum = Decimal.zero;
    for (final b in balances) {
      if (b.kind == kind && (userId == null || b.ownerId == userId)) {
        sum += kind == AccountKind.credit
            ? b.nextBill?.total ?? Decimal.zero
            : b.balance ?? Decimal.zero;
      }
    }
    return Result.success(sum);
  }

  /// Set to make [updateSettings] fail.
  Result<void>? updateForced;
  final List<(String, bool?, String?)> updateCalls = [];

  /// The code the server takes from the account's transfer number when the
  /// flag is turned on without one. Null: there is none, so it answers 422.
  String? transferBankCode = '001';

  @override
  Future<Result<void>> updateSettings(
    String accountId, {
    bool? outgoingTransfersAreIncome,
    String? bankCode,
  }) async {
    updateCalls.add((accountId, outgoingTransfersAreIncome, bankCode));
    final forced = updateForced;
    if (forced != null) return forced;
    final current = balances.where((b) => b.id == accountId).firstOrNull;
    var code = bankCode;
    if (outgoingTransfersAreIncome == true &&
        code == null &&
        current?.bankCode == null) {
      code = transferBankCode;
      if (code == null) return const Result.failure(ValidationFailure());
    }
    balances = [
      for (final b in balances)
        if (b.id == accountId)
          AccountBalance(
            id: b.id,
            ownerId: b.ownerId,
            kind: b.kind,
            name: b.name,
            marketingName: b.marketingName,
            number: b.number,
            balance: b.balance,
            credit: b.credit,
            outgoingTransfersAreIncome:
                outgoingTransfersAreIncome ?? b.outgoingTransfersAreIncome,
            bankCode: code ?? b.bankCode,
            nextBill: b.nextBill,
          )
        else
          b,
    ];
    return const Result.success(null);
  }

  /// What [getCardBill] answers. Null: an empty bill of the asked month.
  Result<CardBill>? billForced;
  final List<(String, DateTime)> billCalls = [];

  /// When set, [getCardBill] waits for it before answering.
  Completer<void>? billGate;

  @override
  Future<Result<CardBill>> getCardBill(
    String accountId, {
    required DateTime month,
  }) async {
    billCalls.add((accountId, month));
    final gate = billGate;
    if (gate != null) await gate.future;
    return billForced ??
        Result.success(
          CardBill(
            accountId: accountId,
            month: DateTime(month.year, month.month),
            total: Decimal.zero,
            estimated: false,
            items: const [],
          ),
        );
  }
}
