import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';

import '../../../support/recurrences_kit.dart';

RecurrenceDraft draft() => RecurrenceDraft(
  description: 'Internet',
  type: EntryType.expenses,
  amount: Decimal.parse('120'),
  dueDay: 10,
);

void main() {
  late RecurrencesKit kit;

  setUp(() => kit = RecurrencesKit());
  tearDown(() => kit.viewModel.dispose());

  List<Recurrence> items() => switch (kit.viewModel.state) {
    UiSuccess<List<Recurrence>>(:final data) => data,
    _ => const [],
  };

  group('load', () {
    test('shows_loading_then_the_recurrences', () async {
      final states = <Type>[];
      kit.viewModel.addListener(
        () => states.add(kit.viewModel.state.runtimeType),
      );

      await kit.viewModel.load();

      expect(states.first, UiLoading<List<Recurrence>>);
      expect(items().map((r) => r.id), ['r1', 'r2']);
    });

    test('no_recurrences_is_the_empty_state', () async {
      kit.repository.all = [];

      await kit.viewModel.load();

      expect(kit.viewModel.state, isA<UiEmpty<List<Recurrence>>>());
    });

    test('a_failure_is_the_error_state', () async {
      kit.repository.failure = const NetworkFailure();

      await kit.viewModel.load();

      expect(
        (kit.viewModel.state as UiError<List<Recurrence>>).failure,
        const NetworkFailure(),
      );
    });

    test('a_failed_refresh_keeps_the_list_on_screen', () async {
      await kit.viewModel.load();
      kit.repository.failure = const NetworkFailure();

      await kit.viewModel.reload();

      expect(items(), hasLength(2));
    });
  });

  group('changes', () {
    test('create_adds_the_recurrence_and_reads_the_list_again', () async {
      await kit.viewModel.load();

      final failure = await kit.viewModel.create(draft());

      expect(failure, isNull);
      expect(kit.repository.created, [draft()]);
      expect(items().map((r) => r.description), contains('Internet'));
      expect(kit.repository.listCalls, 2);
    });

    test('update_replaces_the_data', () async {
      await kit.viewModel.load();

      final failure = await kit.viewModel.update('r1', draft());

      expect(failure, isNull);
      expect(kit.repository.updated.single.$1, 'r1');
      expect(items().firstWhere((r) => r.id == 'r1').description, 'Internet');
    });

    test('delete_removes_the_recurrence', () async {
      await kit.viewModel.load();

      final failure = await kit.viewModel.delete('r1');

      expect(failure, isNull);
      expect(items().map((r) => r.id), ['r2']);
    });

    test(
      'a_failed_change_is_returned_and_the_list_is_not_read_again',
      () async {
        await kit.viewModel.load();
        kit.repository.failure = const ServerUnavailableFailure();

        final failure = await kit.viewModel.delete('r1');

        expect(failure, const ServerUnavailableFailure());
        expect(kit.repository.listCalls, 1);
      },
    );
  });

  group('provisionNextMonth', () {
    test('the_next_month_is_the_one_after_today', () {
      expect(kit.viewModel.nextMonth, DateTime(2026, 12));
      expect(
        RecurrencesKit(now: DateTime(2026, 12, 31)).viewModel.nextMonth,
        DateTime(2027),
      );
    });

    test(
      'returns_what_the_api_created_without_reading_the_list_again',
      () async {
        await kit.viewModel.load();

        final result = await kit.viewModel.provisionNextMonth();

        expect(result.valueOrNull?.created, 2);
        expect(kit.repository.provisionCalls, 1);
        expect(kit.repository.listCalls, 1);
      },
    );

    test('without_recurrences_the_failure_says_so', () async {
      kit.repository.provision = const Result.failure(NoRecurrencesFailure());

      final result = await kit.viewModel.provisionNextMonth();

      expect(result.failureOrNull, const NoRecurrencesFailure());
    });

    test('a_second_tap_while_it_runs_does_not_send_another_request', () async {
      final gate = Completer<Result<ProvisionResult>>();
      kit.repository.gate = gate;

      final first = kit.viewModel.provisionNextMonth();
      expect(kit.viewModel.isProvisioning, isTrue);
      final second = await kit.viewModel.provisionNextMonth();
      gate.complete(kit.repository.provision);
      await first;

      expect(second.isSuccess, isFalse);
      expect(kit.repository.provisionCalls, 1);
      expect(kit.viewModel.isProvisioning, isFalse);
    });
  });
}
