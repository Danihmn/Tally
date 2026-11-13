import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/home/data/datasources/home_remote_data_source.dart';
import 'package:mobile/features/home/data/mappers/home_mappers.dart';
import 'package:mobile/features/home/data/models/home_dtos.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/entry_type.dart';

import '../../../support/fake_dio.dart';
import '../../../support/fake_home_repository.dart';
import '../../../support/fakes.dart';

void main() {
  final range = DateRange(from: DateTime(2026, 11), to: DateTime(2026, 11, 12));

  HomeRemoteDataSource build(FakeHttpAdapter adapter) =>
      HomeRemoteDataSource(buildFakeDio(adapter));

  FakeHttpAdapter answering(Object? body, {int status = 200}) =>
      FakeHttpAdapter((_) => FakeReply(status, body));

  group('amount endpoints', () {
    test('total_expenses_sends_the_period_and_reads_total', () async {
      final adapter = answering({
        'date_from': '2026-11-01',
        'date_to': '2026-11-12',
        'total': '1200.50',
      });

      final result = await build(adapter).totalExpenses(range);

      expect(result.valueOrNull?.value, dec('1200.50'));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/transactions/total-expenses');
      expect(request.queryParameters, {
        'date_from': '2026-11-01',
        'date_to': '2026-11-12',
      });
    });

    test('the_person_is_sent_only_when_there_is_one', () async {
      final adapter = answering({'total': '1.00'});

      await build(adapter).totalRevenues(range, userId: 'm1');
      await build(adapter).totalRevenues(range);

      expect(adapter.requests[0].queryParameters['user_id'], 'm1');
      expect(
        adapter.requests[1].queryParameters.containsKey('user_id'),
        isFalse,
      );
    });

    test('balance_reads_the_balance_key_even_when_negative', () async {
      final adapter = answering({'balance': '-35.00'});

      final result = await build(adapter).balance(range);

      expect(result.valueOrNull?.value, dec('-35.00'));
      expect(adapter.requests.single.path, '/transactions/balance');
    });

    test('average_reads_the_average_key', () async {
      final adapter = answering({'average': 49.95});

      final result = await build(adapter).averageDailyExpenses(range);

      expect(result.valueOrNull?.value, dec('49.95'));
      expect(
        adapter.requests.single.path,
        '/transactions/average-daily-expenses',
      );
    });

    test('a_missing_amount_is_an_unknown_failure', () async {
      final adapter = answering({'date_from': '2026-11-01'});

      final result = await build(adapter).totalExpenses(range);

      expect(result.failureOrNull, const UnknownFailure());
    });

    test('a_401_is_an_unauthorized_failure', () async {
      final adapter = answering({}, status: 401);

      final result = await build(adapter).totalExpenses(range);

      expect(result.failureOrNull, const UnauthorizedFailure());
    });
  });

  group('list endpoints', () {
    test('daily_expenses_reads_one_item_per_day', () async {
      final adapter = answering({
        'items': [
          {'date': '2026-11-01', 'total': '0.00'},
          {'date': '2026-11-02', 'total': '99.90'},
        ],
      });

      final result = await build(adapter).dailyExpenses(range);

      final days = result.valueOrNull!.map((d) => d.toEntity()).toList();
      expect(days.map((d) => d.day), [
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
      ]);
      expect(days.last.amount, dec('99.90'));
      expect(adapter.requests.single.path, '/transactions/daily-expenses');
    });

    test('top_expenses_sends_the_limit_and_accepts_no_description', () async {
      final adapter = answering({
        'items': [
          {'date': '2026-11-10', 'amount': '1500.00', 'description': 'Rent'},
          {'date': '2026-11-03', 'amount': '20.50', 'description': null},
        ],
      });

      final result = await build(adapter).topExpenses(range, limit: 5);

      final items = result.valueOrNull!;
      expect(items.map((i) => i.description), ['Rent', null]);
      expect(adapter.requests.single.queryParameters['limit'], 5);
      expect(adapter.requests.single.path, '/transactions/top-expenses');
    });

    test('an_empty_list_is_fine', () async {
      final adapter = answering({'items': <Object?>[]});

      final result = await build(adapter).dailyExpenses(range);

      expect(result.valueOrNull, isEmpty);
    });
  });

  group('planning endpoints', () {
    test('send_the_type_and_the_period', () async {
      final adapter = answering({'total': '3000.00'});

      await build(adapter)
          .totalPlanned(range, EntryType.expenses, userId: 'm1');

      final request = adapter.requests.single;
      expect(request.path, '/financial-entries/total-planned');
      expect(request.queryParameters, {
        'date_from': '2026-11-01',
        'date_to': '2026-11-12',
        'user_id': 'm1',
        'type': 'EXPENSES',
      });
    });

    test('total_reconciled_uses_its_own_endpoint', () async {
      final adapter = answering({'total': '1800.00'});

      final result = await build(adapter)
          .totalReconciled(range, EntryType.revenues);

      expect(result.valueOrNull?.value, dec('1800.00'));
      expect(
        adapter.requests.single.path,
        '/financial-entries/total-reconciled',
      );
      expect(adapter.requests.single.queryParameters['type'], 'REVENUES');
    });

    test('reconciliation_counts_reads_both_counts', () async {
      final adapter = answering({'reconciled': 3, 'not_reconciled': 2});

      final result = await build(adapter)
          .reconciliationCounts(range, EntryType.expenses);

      final counts = result.valueOrNull!.toEntity();
      expect((counts.reconciled, counts.notReconciled), (3, 2));
    });

    test('counts_that_are_not_whole_numbers_are_an_unknown_failure', () async {
      final adapter = answering({'reconciled': '3', 'not_reconciled': 2});

      final result = await build(adapter)
          .reconciliationCounts(range, EntryType.expenses);

      expect(result.failureOrNull, const UnknownFailure());
    });
  });

  group('upcoming entries', () {
    test('sends_the_days_and_reads_the_items', () async {
      final adapter = answering({
        'items': [
          {
            'description': 'Rent',
            'amount': '1500.00',
            'type': 'EXPENSES',
            'category': 'Moradia',
            'due_date': '2026-11-15',
          },
          {
            'description': 'Salary',
            'amount': '5000.00',
            'type': 'REVENUES',
            'category': null,
            'due_date': '2026-11-18',
          },
        ],
      });

      final result = await build(adapter).upcomingEntries(days: 30);

      final entries = result.valueOrNull!.map((e) => e.toEntity()).toList();
      expect(entries.map((e) => e.isIncome), [false, true]);
      expect(entries.map((e) => e.category), ['Moradia', null]);
      expect(entries.first.dueDate, DateTime(2026, 11, 15));
      final request = adapter.requests.single;
      expect(request.path, '/financial-entries/upcoming');
      expect(request.queryParameters, {'days': 30});
    });

    test('an_older_api_without_category_still_works', () async {
      final adapter = answering({
        'items': [
          {
            'description': 'Rent',
            'amount': '1500.00',
            'type': 'EXPENSES',
            'due_date': '2026-11-15',
          },
        ],
      });

      final result = await build(adapter)
          .upcomingEntries(days: 7, userId: 'm1');

      expect(result.valueOrNull!.single.category, isNull);
      expect(adapter.requests.single.queryParameters['user_id'], 'm1');
    });

    test('an_invalid_due_date_is_an_unknown_failure', () async {
      final adapter = answering({
        'items': [
          {
            'description': 'Rent',
            'amount': '1.00',
            'type': 'EXPENSES',
            'due_date': '2026-13-45',
          },
        ],
      });

      final result = await build(adapter).upcomingEntries(days: 7);

      expect(result.failureOrNull, const UnknownFailure());
    });
  });

  group('UpcomingEntryDto', () {
    test('maps_the_revenue_type_to_income', () {
      final dto = UpcomingEntryDto.fromJson({
        'description': 'Salary',
        'amount': '1',
        'type': 'REVENUES',
        'due_date': '2026-11-18',
      });

      expect(dto.toEntity().isIncome, isTrue);
    });
  });
}
