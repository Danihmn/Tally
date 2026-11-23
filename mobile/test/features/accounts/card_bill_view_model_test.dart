import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/accounts/domain/entities/card_bill.dart';
import 'package:mobile/features/accounts/domain/usecases/get_card_bill.dart';
import 'package:mobile/features/accounts/presentation/viewmodels/card_bill_view_model.dart';

import '../../support/fake_transactions_repository.dart';

void main() {
  late FakeAccountsRepository repository;

  setUp(() => repository = FakeAccountsRepository());

  CardBillViewModel build({DateTime? today}) => CardBillViewModel(
    accountId: 'c1',
    getBill: GetCardBill(repository),
    now: () => today ?? DateTime(2026, 11, 23),
  );

  group('CardBillViewModel', () {
    test('starts_at_the_bill_due_next_month', () {
      final vm = build();

      expect(vm.month, DateTime(2026, 12));
      expect(vm.state, isA<UiInitial<CardBill>>());
    });

    test('in_december_next_month_is_january', () {
      expect(build(today: DateTime(2026, 12, 31)).month, DateTime(2027));
    });

    test('load_asks_for_the_card_and_the_month', () async {
      final vm = build();

      await vm.load();

      expect(repository.billCalls.single, ('c1', DateTime(2026, 12)));
      expect(vm.state, isA<UiSuccess<CardBill>>());
    });

    test('the_arrows_move_one_month_and_load_it', () async {
      final vm = build();

      await vm.nextMonth();
      await vm.previousMonth();
      await vm.previousMonth();

      expect(repository.billCalls.map((c) => c.$2), [
        DateTime(2027),
        DateTime(2026, 12),
        DateTime(2026, 11),
      ]);
      expect(vm.month, DateTime(2026, 11));
    });

    test('a_failure_becomes_an_error_state', () async {
      repository.billForced = const Result.failure(NetworkFailure());
      final vm = build();

      await vm.load();

      expect(vm.state, isA<UiError<CardBill>>());
    });

    test('shows_loading_while_the_bill_comes', () async {
      repository.billGate = Completer<void>();
      final vm = build();

      final loading = vm.load();
      expect(vm.state, isA<UiLoading<CardBill>>());
      repository.billGate!.complete();
      await loading;

      expect(vm.state, isA<UiSuccess<CardBill>>());
    });

    test('a_slow_answer_of_a_month_already_left_is_dropped', () async {
      final gate = Completer<void>();
      repository.billGate = gate;
      final vm = build();
      final first = vm.load(); // December, still waiting
      repository.billGate = null;

      await vm.nextMonth(); // January answers at once
      gate.complete();
      await first;

      final state = vm.state as UiSuccess<CardBill>;
      expect(state.data.month, DateTime(2027));
      expect(vm.month, DateTime(2027));
    });
  });
}
