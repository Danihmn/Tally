import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/entries/data/datasources/entries_remote_data_source.dart';
import 'package:mobile/features/entries/data/mappers/financial_entry_mapper.dart';
import 'package:mobile/features/entries/data/models/financial_entry_dto.dart';
import 'package:mobile/features/entries/data/repositories/entries_repository_impl.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/usecases/search_entries.dart';

import '../../../support/fake_dio.dart';
import '../../../support/fakes.dart';

Map<String, dynamic> item({
  String id = 'e1',
  String type = 'EXPENSES',
  Object? paymentType = 'DEBIT',
  String status = 'PLANNED',
  Object? dueDate = '2026-11-20',
  Object? category = 'Moradia',
  Object? bankAccountId = 'a1',
  Object? installmentNumber,
  Object? installmentTotal,
  Object? notes,
}) => {
  'id': id,
  'user_id': 'm1',
  'bank_account_id': bankAccountId,
  'description': 'Aluguel',
  'category': category,
  'type': type,
  'payment_type': paymentType,
  'amount': '1500.00',
  'currency_code': 'BRL',
  'reference_month': '2026-11-01',
  'due_date': dueDate,
  'status': status,
  'installment_number': installmentNumber,
  'installment_total': installmentTotal,
  'notes': notes,
  'recurrence_id': null,
  'created_at': '2026-11-01T09:00:00Z',
  'updated_at': null,
};

Map<String, dynamic> page(
  List<Map<String, dynamic>> items, {
  int total = 41,
  int limit = 30,
  int offset = 0,
}) => {'items': items, 'total': total, 'limit': limit, 'offset': offset};

void main() {
  group('FinancialEntryDto', () {
    test('reads_the_fields_the_screen_uses', () {
      final entry = FinancialEntryDto.fromJson(
        item(installmentNumber: 2, installmentTotal: 5, notes: 'Contrato'),
      ).toEntity();

      expect(entry.id, 'e1');
      expect(entry.ownerId, 'm1');
      expect(entry.accountId, 'a1');
      expect(entry.description, 'Aluguel');
      expect(entry.category, 'Moradia');
      expect(entry.type, EntryType.expenses);
      expect(entry.paymentType, PaymentType.debit);
      expect(entry.amount, Decimal.parse('1500.00'));
      expect(entry.referenceMonth, DateTime(2026, 11));
      expect(entry.dueDate, DateTime(2026, 11, 20));
      expect(entry.status, EntryStatus.planned);
      expect(entry.installmentLabel, '2/5');
      expect(entry.notes, 'Contrato');
      expect(entry.createdAt, DateTime.utc(2026, 11, 1, 9));
    });

    test('revenues_credit_and_the_other_statuses_are_mapped', () {
      final reconciled = FinancialEntryDto.fromJson(
        item(type: 'REVENUES', paymentType: 'CREDIT', status: 'RECONCILED'),
      ).toEntity();
      final cancelled = FinancialEntryDto.fromJson(item(status: 'CANCELLED'))
          .toEntity();

      expect(reconciled.type, EntryType.revenues);
      expect(reconciled.paymentType, PaymentType.credit);
      expect(reconciled.status, EntryStatus.reconciled);
      expect(cancelled.status, EntryStatus.cancelled);
    });

    test(
      'the_due_date_the_category_the_account_and_the_payment_may_be_null',
      () {
        final entry = FinancialEntryDto.fromJson(
          item(
            dueDate: null,
            category: null,
            bankAccountId: null,
            paymentType: null,
          ),
        ).toEntity();

        expect(entry.dueDate, isNull);
        expect(entry.category, isNull);
        expect(entry.accountId, isNull);
        expect(entry.paymentType, isNull);
      },
    );

    test('the_amount_may_come_as_a_number', () {
      final dto = FinancialEntryDto.fromJson({...item(), 'amount': 10.5});

      expect(dto.amount, Decimal.parse('10.5'));
    });

    test('a_missing_required_field_is_a_format_error', () {
      final broken = item()..remove('description');

      expect(() => FinancialEntryDto.fromJson(broken), throwsFormatException);
    });

    test('an_invalid_date_is_a_format_error', () {
      expect(
        () => FinancialEntryDto.fromJson(item(dueDate: '20/11/2026')),
        throwsFormatException,
      );
    });
  });

  group('EntriesRemoteDataSource', () {
    EntriesRemoteDataSource build(FakeHttpAdapter adapter) =>
        EntriesRemoteDataSource(buildFakeDio(adapter));

    FakeHttpAdapter answering(Object? body, {int status = 200}) =>
        FakeHttpAdapter((_) => FakeReply(status, body));

    test('asks_for_the_page_and_reads_the_total', () async {
      final adapter = answering(page([item()], offset: 30));

      final result = await build(adapter).search(offset: 30, limit: 30);

      final dto = result.valueOrNull!;
      expect(dto.items, hasLength(1));
      expect((dto.total, dto.limit, dto.offset), (41, 30, 30));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/financial-entries');
      expect(request.queryParameters, {'limit': 30, 'offset': 30});
    });

    test('every_filter_is_sent_with_the_name_the_api_expects', () async {
      final adapter = answering(page([]));
      final filters = EntryFilters(
        accountId: 'a1',
        type: EntryType.revenues,
        paymentType: PaymentType.credit,
        dueFrom: DateTime(2026, 11),
        dueTo: DateTime(2026, 11, 30),
        minAmount: Decimal.parse('10.50'),
        maxAmount: Decimal.parse('200'),
      );

      await build(adapter).search(
        offset: 0,
        limit: 30,
        userId: 'm2',
        status: EntryStatus.reconciled,
        referenceMonth: DateTime(2026, 11, 17),
        filters: filters,
        search: 'luz',
      );

      expect(adapter.requests.single.queryParameters, {
        'limit': 30,
        'offset': 0,
        'user_id': 'm2',
        'status': 'RECONCILED',
        'reference_month_from': '2026-11-01',
        'reference_month_to': '2026-11-01',
        'bank_account_id': 'a1',
        'type': 'REVENUES',
        'payment_type': 'CREDIT',
        'due_date_from': '2026-11-01',
        'due_date_to': '2026-11-30',
        'min_amount': '10.5',
        'max_amount': '200',
        'search': 'luz',
      });
    });

    test('the_transaction_id_is_sent_to_find_the_linked_entry', () async {
      final adapter = answering(page([]));

      await build(adapter).search(offset: 0, limit: 5, transactionId: 't9');

      expect(adapter.requests.single.queryParameters['transaction_id'], 't9');
    });

    test(
      'the_search_text_is_trimmed_cut_and_an_empty_one_is_not_sent',
      () async {
        final adapter = answering(page([]));

        await build(adapter).search(offset: 0, limit: 30, search: '  luz  ');
        await build(adapter).search(offset: 0, limit: 30, search: '   ');
        await build(adapter).search(offset: 0, limit: 30, search: 'a' * 150);

        expect(adapter.requests[0].queryParameters['search'], 'luz');
        expect(
          adapter.requests[1].queryParameters.containsKey('search'),
          isFalse,
        );
        expect(
          (adapter.requests[2].queryParameters['search'] as String).length,
          EntriesRemoteDataSource.maxSearchLength,
        );
      },
    );

    test('a_422_is_a_validation_failure_and_a_401_is_unauthorized', () async {
      final invalid = await build(
        answering({'detail': <Object?>[]}, status: 422),
      ).search(offset: 0, limit: 30);
      final denied = await build(answering({}, status: 401))
          .search(offset: 0, limit: 30);

      expect(invalid.failureOrNull, isA<ValidationFailure>());
      expect(denied.failureOrNull, const UnauthorizedFailure());
    });
  });

  group('repository and use case', () {
    SearchEntries build(FakeHttpAdapter adapter) => SearchEntries(
      EntriesRepositoryImpl(EntriesRemoteDataSource(buildFakeDio(adapter))),
    );

    test('the_page_has_entities_and_the_total_of_the_api', () async {
      final adapter = FakeHttpAdapter(
        (_) => FakeReply(200, page([item(id: 'a'), item(id: 'b')], total: 41)),
      );

      final result = await build(adapter)(offset: 0, limit: 30);

      final page_ = result.valueOrNull!;
      expect(page_.items.map((e) => e.id), ['a', 'b']);
      expect(page_.total, 41);
    });

    test('a_failure_goes_through_unchanged', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(503, {}));

      final result = await build(adapter)(offset: 0, limit: 30);

      expect(result.failureOrNull, const ServerUnavailableFailure());
    });
  });
}
