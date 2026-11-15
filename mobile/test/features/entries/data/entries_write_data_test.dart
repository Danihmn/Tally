import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/entries/data/datasources/entries_remote_data_source.dart';
import 'package:mobile/features/entries/data/repositories/entries_repository_impl.dart';
import 'package:mobile/features/entries/domain/entities/entry_draft.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/usecases/create_entry.dart';
import 'package:mobile/features/entries/domain/usecases/delete_entry.dart';
import 'package:mobile/features/entries/domain/usecases/set_entry_status.dart';
import 'package:mobile/features/entries/domain/usecases/update_entry.dart';

import '../../../support/entry_factory.dart';
import '../../../support/fake_dio.dart';
import '../../../support/fakes.dart';
import 'entries_data_test.dart' show item;

EntryDraft draft({
  String? category = 'Moradia',
  DateTime? dueDate,
  int? installmentNumber,
  int? installmentTotal,
}) => EntryDraft(
  description: '  Aluguel ',
  type: EntryType.expenses,
  amount: Decimal.parse('1500'),
  referenceMonth: DateTime(2026, 12, 17),
  paymentType: PaymentType.debit,
  category: category,
  dueDate: dueDate,
  accountId: 'a1',
  installmentNumber: installmentNumber,
  installmentTotal: installmentTotal,
);

void main() {
  FakeHttpAdapter answering(Object? body, {int status = 200}) =>
      FakeHttpAdapter((_) => FakeReply(status, body));

  EntriesRemoteDataSource build(FakeHttpAdapter adapter) =>
      EntriesRemoteDataSource(buildFakeDio(adapter));

  group('EntriesRemoteDataSource create', () {
    test('posts_every_field_of_the_form_with_the_names_of_the_api', () async {
      final adapter = answering(item(), status: 201);

      final result = await build(adapter).create(
        draft(
          dueDate: DateTime(2026, 12, 5),
          installmentNumber: 2,
          installmentTotal: 5,
        ),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/financial-entries');
      expect(request.data, {
        'description': 'Aluguel',
        'type': 'EXPENSES',
        'amount': '1500.00',
        // Any day of the month becomes day 1.
        'reference_month': '2026-12-01',
        'payment_type': 'DEBIT',
        'category': 'Moradia',
        'due_date': '2026-12-05',
        'bank_account_id': 'a1',
        'installment_number': 2,
        'installment_total': 5,
        'notes': null,
      });
      expect(result.valueOrNull?.id, 'e1');
    });

    test('a_422_is_a_validation_failure', () async {
      final adapter = answering({'detail': 'Invalid data'}, status: 422);

      final result = await build(adapter).create(draft());

      expect(result.failureOrNull, const ValidationFailure());
    });
  });

  group('EntriesRemoteDataSource update', () {
    test(
      'patches_the_entry_with_the_whole_form_so_empty_fields_clear',
      () async {
        final adapter = answering(item());

        await build(adapter).update('e9', draft(category: null));

        final request = adapter.requests.single;
        expect(request.method, 'PATCH');
        expect(request.path, '/financial-entries/e9');
        final body = request.data as Map<String, dynamic>;
        expect(body['category'], isNull);
        expect(body.containsKey('category'), isTrue);
        expect(body['due_date'], isNull);
        expect(body['description'], 'Aluguel');
      },
    );

    test('setting_the_status_sends_only_the_status', () async {
      final adapter = answering(item(status: 'CANCELLED'));

      final result = await build(adapter)
          .setStatus('e9', EntryStatus.cancelled);

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/financial-entries/e9');
      expect(request.data, {'status': 'CANCELLED'});
      expect(result.valueOrNull?.status, 'CANCELLED');
    });

    test('a_404_is_not_found', () async {
      final adapter = answering({'detail': 'Record not found'}, status: 404);

      final result = await build(adapter).setStatus('x', EntryStatus.planned);

      expect(result.failureOrNull, const NotFoundFailure());
    });
  });

  group('EntriesRemoteDataSource delete', () {
    test('deletes_the_entry_by_id', () async {
      final adapter = answering(null, status: 204);

      final result = await build(adapter).delete('e9');

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/financial-entries/e9');
      expect(result.isSuccess, isTrue);
    });

    test('a_reconciled_entry_is_refused_with_a_validation_failure', () async {
      final adapter = answering({'detail': 'Invalid data'}, status: 422);

      final result = await build(adapter).delete('e9');

      expect(result.failureOrNull, const ValidationFailure());
    });
  });

  group('repository and use cases', () {
    test('the_created_entry_comes_back_as_an_entity', () async {
      final repository = EntriesRepositoryImpl(
        build(answering(item(), status: 201)),
      );

      final result = await CreateEntry(repository)(draft());

      expect(result.valueOrNull?.description, 'Aluguel');
      expect(result.valueOrNull?.type, EntryType.expenses);
    });

    test('update_status_and_delete_go_through', () async {
      final adapter = answering(item());
      final repository = EntriesRepositoryImpl(build(adapter));

      expect((await UpdateEntry(repository)('e1', draft())).isSuccess, isTrue);
      expect(
        (await SetEntryStatus(repository)('e1', EntryStatus.planned)).isSuccess,
        isTrue,
      );
      expect((await DeleteEntry(repository)('e1')).isSuccess, isTrue);
      expect(adapter.requests.map((r) => r.method), [
        'PATCH',
        'PATCH',
        'DELETE',
      ]);
    });

    test('a_failure_goes_through_unchanged', () async {
      final repository = EntriesRepositoryImpl(
        build(answering({'detail': 'x'}, status: 503)),
      );

      final result = await CreateEntry(repository)(draft());

      expect(result.failureOrNull, const ServerUnavailableFailure());
    });

    test('an_entry_draft_starts_from_an_entry', () {
      final entry = makeEntry(
        notes: 'n',
        installmentNumber: 1,
        installmentTotal: 3,
      );

      final fromEntry = EntryDraft.fromEntry(entry);

      expect(fromEntry.description, entry.description);
      expect(fromEntry.amount, entry.amount);
      expect(fromEntry.accountId, entry.accountId);
      expect(fromEntry.installmentTotal, 3);
      expect(fromEntry.notes, 'n');
    });
  });
}
