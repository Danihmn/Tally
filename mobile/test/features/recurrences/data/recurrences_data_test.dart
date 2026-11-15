import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/recurrences/data/datasources/recurrences_remote_data_source.dart';
import 'package:mobile/features/recurrences/data/mappers/recurrence_mapper.dart';
import 'package:mobile/features/recurrences/data/models/recurrence_dto.dart';
import 'package:mobile/features/recurrences/data/repositories/recurrences_repository_impl.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/provision_next_month.dart';

import '../../../support/fake_dio.dart';
import '../../../support/fakes.dart';
import '../../../support/recurrence_factory.dart';

Map<String, dynamic> item({
  String id = 'r1',
  String type = 'EXPENSES',
  Object? paymentType = 'DEBIT',
  Object? dueDay = 5,
  Object? category = 'Moradia',
}) => {
  'id': id,
  'user_id': 'm1',
  'description': 'Aluguel',
  'type': type,
  'amount': '1500.00',
  'currency_code': 'BRL',
  'source': 'MANUAL',
  'category': category,
  'payment_type': paymentType,
  'notes': null,
  'due_day': dueDay,
  'created_at': '2026-11-01T09:00:00Z',
  'updated_at': null,
};

RecurrenceDraft draft({int? dueDay = 5, String? category}) => RecurrenceDraft(
  description: ' Aluguel ',
  type: EntryType.expenses,
  amount: Decimal.parse('1500'),
  paymentType: PaymentType.debit,
  dueDay: dueDay,
  category: category,
);

void main() {
  FakeHttpAdapter answering(Object? body, {int status = 200}) =>
      FakeHttpAdapter((_) => FakeReply(status, body));

  RecurrencesRemoteDataSource build(FakeHttpAdapter adapter) =>
      RecurrencesRemoteDataSource(buildFakeDio(adapter));

  group('RecurrenceDto', () {
    test('reads_the_fields_the_screen_uses', () {
      final recurrence = RecurrenceDto.fromJson(item()).toEntity();

      expect(recurrence.id, 'r1');
      expect(recurrence.type, EntryType.expenses);
      expect(recurrence.paymentType, PaymentType.debit);
      expect(recurrence.amount, Decimal.parse('1500'));
      expect(recurrence.dueDay, 5);
      expect(recurrence.category, 'Moradia');
    });

    test('revenues_credit_and_missing_optionals_are_mapped', () {
      final recurrence = RecurrenceDto.fromJson(
        item(type: 'REVENUES', paymentType: null, dueDay: null, category: null),
      ).toEntity();

      expect(recurrence.isRevenue, isTrue);
      expect(recurrence.paymentType, isNull);
      expect(recurrence.dueDay, isNull);
      expect(recurrence.category, isNull);
    });

    test('a_missing_required_field_is_a_format_error', () {
      final json = item()..remove('description');

      expect(() => RecurrenceDto.fromJson(json), throwsFormatException);
    });
  });

  group('RecurrencesRemoteDataSource', () {
    test('lists_the_recurrences_of_the_page_with_the_largest_limit', () async {
      final adapter = answering({
        'items': [item(), item(id: 'r2')],
        'total': 2,
        'limit': 200,
        'offset': 0,
      });

      final result = await build(adapter).list();

      expect(result.valueOrNull, hasLength(2));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/recurrences');
      expect(request.queryParameters, {'limit': 200});
    });

    test('creates_with_every_field_of_the_form', () async {
      final adapter = answering(item(), status: 201);

      final result = await build(adapter).create(draft());

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/recurrences');
      expect(request.data, {
        'description': 'Aluguel',
        'type': 'EXPENSES',
        'amount': '1500.00',
        'payment_type': 'DEBIT',
        'due_day': 5,
        'category': null,
        'notes': null,
      });
      expect(result.valueOrNull?.id, 'r1');
    });

    test('updates_by_id_sending_nulls_to_clear_fields', () async {
      final adapter = answering(item());

      await build(adapter).update('r9', draft(dueDay: null));

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/recurrences/r9');
      final body = request.data as Map<String, dynamic>;
      expect(body.containsKey('due_day'), isTrue);
      expect(body['due_day'], isNull);
    });

    test('deletes_by_id', () async {
      final adapter = answering(null, status: 204);

      final result = await build(adapter).delete('r9');

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/recurrences/r9');
      expect(result.isSuccess, isTrue);
    });

    test('provisioning_posts_without_a_body_and_reads_the_counts', () async {
      final adapter = answering({
        'reference_month': '2026-12-01',
        'created': 3,
        'skipped': 1,
      });

      final result = await build(adapter).provisionNextMonth();

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/recurrences/provision');
      final dto = result.valueOrNull!;
      expect(dto.referenceMonth, DateTime(2026, 12));
      expect((dto.created, dto.skipped), (3, 1));
    });

    test('provisioning_without_recurrences_is_its_own_failure', () async {
      final adapter = answering({
        'detail': 'No recurrences to provision',
        'code': 'NO_RECURRENCES',
      }, status: 422);

      final result = await build(adapter).provisionNextMonth();

      expect(result.failureOrNull, const NoRecurrencesFailure());
    });

    test('a_422_on_create_is_a_validation_failure', () async {
      final adapter = answering({'detail': 'Invalid data'}, status: 422);

      final result = await build(adapter).create(draft());

      expect(result.failureOrNull, const ValidationFailure());
    });
  });

  group('repository and use cases', () {
    test('the_list_has_entities', () async {
      final repository = RecurrencesRepositoryImpl(
        build(
          answering({
            'items': [item()],
            'total': 1,
            'limit': 200,
            'offset': 0,
          }),
        ),
      );

      final result = await repository.list();

      expect(result.valueOrNull, [makeRecurrence(notes: null)]);
    });

    test('provisioning_returns_the_result_as_an_entity', () async {
      final repository = RecurrencesRepositoryImpl(
        build(
          answering({
            'reference_month': '2026-12-01',
            'created': 2,
            'skipped': 0,
          }),
        ),
      );

      final result = await ProvisionNextMonth(repository)();

      expect(
        result.valueOrNull,
        ProvisionResult(
          referenceMonth: DateTime(2026, 12),
          created: 2,
          skipped: 0,
        ),
      );
    });

    test('a_recurrence_draft_starts_from_a_recurrence', () {
      final recurrence = makeRecurrence(notes: 'n');

      final fromRecurrence = RecurrenceDraft.fromRecurrence(recurrence);

      expect(fromRecurrence.description, 'Aluguel');
      expect(fromRecurrence.dueDay, 5);
      expect(fromRecurrence.notes, 'n');
    });
  });
}
