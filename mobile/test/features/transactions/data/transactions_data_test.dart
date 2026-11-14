import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/transactions/data/datasources/transactions_remote_data_source.dart';
import 'package:mobile/features/transactions/data/mappers/transaction_mapper.dart';
import 'package:mobile/features/transactions/data/models/transaction_dto.dart';
import 'package:mobile/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';
import 'package:mobile/features/transactions/domain/usecases/search_transactions.dart';

import '../../../support/fake_dio.dart';
import '../../../support/fakes.dart';

Map<String, dynamic> item({
  String id = 't1',
  String amount = '-120.50',
  String type = 'DEBIT',
  String status = 'POSTED',
  Object? merchant,
  Object? description = 'Mercado',
  Object? category,
  Object? balance,
}) => {
  'id': id,
  'bank_account_id': 'a1',
  'user_id': 'm1',
  'date': '2026-11-05T00:00:00Z',
  'description': description,
  'amount': amount,
  'currency_code': 'BRL',
  'type': type,
  'status': status,
  'category': category,
  'category_id': category == null ? null : '10000000',
  'merchant': merchant,
  'balance': balance,
};

Map<String, dynamic> page(
  List<Map<String, dynamic>> items, {
  int total = 75,
  int limit = 30,
  int offset = 0,
}) => {'items': items, 'total': total, 'limit': limit, 'offset': offset};

void main() {
  group('TransactionDto', () {
    test('reads_the_fields_the_screen_uses', () {
      final dto = TransactionDto.fromJson(
        item(
          merchant: {'name': 'Pão de Açúcar', 'cnpj': '1'},
          category: 'Groceries',
          balance: '900.00',
        ),
      );
      final transaction = dto.toEntity();

      expect(transaction.id, 't1');
      expect(transaction.accountId, 'a1');
      expect(transaction.ownerId, 'm1');
      expect(transaction.date, DateTime.utc(2026, 11, 5));
      expect(transaction.description, 'Mercado');
      expect(transaction.amount, Decimal.parse('-120.50'));
      expect(transaction.direction, TransactionDirection.debit);
      expect(transaction.status, TransactionStatus.posted);
      expect(transaction.category, 'Groceries');
      expect(transaction.categoryId, '10000000');
      expect(transaction.merchantName, 'Pão de Açúcar');
      expect(transaction.balance, Decimal.parse('900.00'));
    });

    test('a_credit_and_a_pending_status_are_mapped', () {
      final transaction = TransactionDto.fromJson(
        item(type: 'CREDIT', status: 'PENDING'),
      ).toEntity();

      expect(transaction.direction, TransactionDirection.credit);
      expect(transaction.isPending, isTrue);
    });

    test('the_merchant_name_falls_back_to_the_business_name', () {
      final dto = TransactionDto.fromJson(
        item(merchant: {'name': '  ', 'businessName': 'PADARIA LTDA'}),
      );

      expect(dto.merchantName, 'PADARIA LTDA');
    });

    test('a_merchant_without_a_name_or_not_an_object_is_ignored', () {
      expect(TransactionDto.fromJson(item()).merchantName, isNull);
      expect(
        TransactionDto.fromJson(item(merchant: {'cnpj': '1'})).merchantName,
        isNull,
      );
      expect(
        TransactionDto.fromJson(item(merchant: 'text')).merchantName,
        isNull,
      );
    });

    test('the_description_the_category_and_the_balance_may_be_null', () {
      final dto = TransactionDto.fromJson(item(description: null));

      expect(dto.description, isNull);
      expect(dto.category, isNull);
      expect(dto.categoryId, isNull);
      expect(dto.balance, isNull);
    });

    test('the_amount_may_come_as_a_number', () {
      final dto = TransactionDto.fromJson({...item(), 'amount': -10.5});

      expect(dto.amount, Decimal.parse('-10.5'));
    });

    test('a_missing_required_field_is_a_format_error', () {
      final broken = item()..remove('bank_account_id');

      expect(() => TransactionDto.fromJson(broken), throwsFormatException);
    });

    test('an_invalid_date_is_a_format_error', () {
      expect(
        () => TransactionDto.fromJson({...item(), 'date': 'ontem'}),
        throwsFormatException,
      );
    });
  });

  group('TransactionsRemoteDataSource', () {
    TransactionsRemoteDataSource build(FakeHttpAdapter adapter) =>
        TransactionsRemoteDataSource(buildFakeDio(adapter));

    FakeHttpAdapter answering(Object? body, {int status = 200}) =>
        FakeHttpAdapter((_) => FakeReply(status, body));

    test('asks_for_the_page_and_reads_the_total', () async {
      final adapter = answering(
        page([item()], total: 75, limit: 30, offset: 30),
      );

      final result = await build(adapter).search(offset: 30, limit: 30);

      final dto = result.valueOrNull!;
      expect(dto.items, hasLength(1));
      expect((dto.total, dto.limit, dto.offset), (75, 30, 30));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/transactions');
      expect(request.queryParameters, {'limit': 30, 'offset': 30});
    });

    test('without_filters_only_the_page_is_sent', () async {
      final adapter = answering(page([]));

      await build(adapter).search(offset: 0, limit: 30);

      expect(adapter.requests.single.queryParameters, {
        'limit': 30,
        'offset': 0,
      });
    });

    test('every_filter_is_sent_with_the_name_the_api_expects', () async {
      final adapter = answering(page([]));
      final filters = TransactionFilters(
        accountId: 'a1',
        direction: TransactionDirection.credit,
        status: TransactionStatus.pending,
        dateFrom: DateTime(2026, 11, 1),
        dateTo: DateTime(2026, 11, 12),
        minAmount: Decimal.parse('10.50'),
        maxAmount: Decimal.parse('200'),
      );

      await build(adapter).search(
        offset: 0,
        limit: 30,
        userId: 'm2',
        filters: filters,
        search: 'mercado',
      );

      expect(adapter.requests.single.queryParameters, {
        'limit': 30,
        'offset': 0,
        'user_id': 'm2',
        'bank_account_id': 'a1',
        'type': 'CREDIT',
        'status': 'PENDING',
        'date_from': '2026-11-01',
        'date_to': '2026-11-12',
        'min_amount': '10.5',
        'max_amount': '200',
        'search': 'mercado',
      });
    });

    test('the_entry_that_a_transaction_is_matched_with_can_be_asked', () async {
      final adapter = answering(page([]));

      await build(adapter).search(offset: 0, limit: 5, financialEntryId: 'e1');

      expect(
        adapter.requests.single.queryParameters['financial_entry_id'],
        'e1',
      );
    });

    test('the_search_text_is_trimmed_and_an_empty_one_is_not_sent', () async {
      final adapter = answering(page([]));

      await build(adapter).search(offset: 0, limit: 30, search: '  ifood  ');
      await build(adapter).search(offset: 0, limit: 30, search: '   ');

      expect(adapter.requests[0].queryParameters['search'], 'ifood');
      expect(
        adapter.requests[1].queryParameters.containsKey('search'),
        isFalse,
      );
    });

    test('a_search_text_longer_than_the_api_accepts_is_cut', () async {
      final adapter = answering(page([]));

      await build(adapter).search(offset: 0, limit: 30, search: 'a' * 150);

      expect(
        (adapter.requests.single.queryParameters['search'] as String).length,
        TransactionsRemoteDataSource.maxSearchLength,
      );
    });

    test('a_422_is_a_validation_failure', () async {
      final adapter = answering({'detail': <Object?>[]}, status: 422);

      final result = await build(adapter).search(offset: 0, limit: 30);

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('a_401_is_an_unauthorized_failure', () async {
      final adapter = answering({}, status: 401);

      final result = await build(adapter).search(offset: 0, limit: 30);

      expect(result.failureOrNull, const UnauthorizedFailure());
    });

    test('a_page_without_the_total_is_an_unknown_failure', () async {
      final adapter = answering({
        'items': <Object?>[],
        'limit': 30,
        'offset': 0,
      });

      final result = await build(adapter).search(offset: 0, limit: 30);

      expect(result.failureOrNull, const UnknownFailure());
    });
  });

  group('repository and use case', () {
    SearchTransactions build(FakeHttpAdapter adapter) => SearchTransactions(
      TransactionsRepositoryImpl(
        TransactionsRemoteDataSource(buildFakeDio(adapter)),
      ),
    );

    test('the_page_has_entities_and_the_total_of_the_api', () async {
      final adapter = FakeHttpAdapter(
        (_) => FakeReply(200, page([item(id: 'a'), item(id: 'b')], total: 75)),
      );

      final result = await build(adapter)(offset: 0, limit: 30);

      final result_ = result.valueOrNull!;
      expect(result_.items.map((t) => t.id), ['a', 'b']);
      expect(result_.total, 75);
      expect(result_.limit, 30);
    });

    test('the_arguments_reach_the_api', () async {
      final adapter = FakeHttpAdapter((_) => FakeReply(200, page([])));

      await build(adapter)(
        offset: 60,
        limit: 30,
        userId: 'm1',
        search: 'uber',
        filters: const TransactionFilters(accountId: 'a9'),
      );

      expect(adapter.requests.single.queryParameters, {
        'limit': 30,
        'offset': 60,
        'user_id': 'm1',
        'bank_account_id': 'a9',
        'search': 'uber',
      });
    });

    test('a_failure_goes_through_unchanged', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(503, {}));

      final result = await build(adapter)(offset: 0, limit: 30);

      expect(result.failureOrNull, const ServerUnavailableFailure());
    });
  });
}
