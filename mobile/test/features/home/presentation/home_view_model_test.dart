import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/home/domain/entities/spending_summary.dart';
import 'package:mobile/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

import '../../../support/fake_home_repository.dart';
import '../../../support/home_kit.dart';

void main() {
  late HomeKit kit;

  Future<HomeKit> loaded({DateTime? now, List<Member>? users}) async {
    kit = users == null ? HomeKit(now: now) : HomeKit(now: now, users: users);
    await kit.viewModel.load();
    return kit;
  }

  tearDown(() => kit.dispose());

  group('load', () {
    test('loads_the_profile_and_every_section', () async {
      await loaded();
      final vm = kit.viewModel;

      expect(vm.profile, isA<UiSuccess<HomeProfile>>());
      expect(vm.summary, isA<UiSuccess<Object?>>());
      expect(vm.planning, isA<UiSuccess<Object?>>());
      expect(vm.daily, isA<UiSuccess<Object?>>());
      expect(vm.topExpenses, isA<UiSuccess<Object?>>());
      expect(vm.upcoming, isA<UiSuccess<Object?>>());
    });

    test('starts_with_the_logged_person_and_the_current_month', () async {
      await loaded();
      final vm = kit.viewModel;

      expect(vm.scope?.kind, ScopeKind.me);
      expect(vm.scope?.userId, 'm1');
      expect(vm.period.firstDay, DateTime(2026, 11));
    });

    test('the_numbers_go_from_day_one_until_yesterday', () async {
      await loaded();

      expect(
        kit.home.calls,
        containsAll([
          'totalExpenses 2026-11-01..2026-11-12 user=m1',
          'dailyExpenses 2026-11-01..2026-11-12 user=m1',
          'topExpenses 2026-11-01..2026-11-12 limit=5 user=m1',
        ]),
      );
    });

    test('the_planning_uses_the_whole_month', () async {
      await loaded();

      expect(
        kit.home.calls,
        contains('totalPlanned 2026-11-01..2026-11-30 EXPENSES user=m1'),
      );
    });

    test('the_upcoming_entries_look_thirty_days_ahead', () async {
      await loaded();

      expect(kit.home.calls, contains('upcomingEntries days=30 user=m1'));
    });

    test('the_options_are_me_the_others_and_the_house', () async {
      await loaded();

      expect(kit.viewModel.scopeOptions.map((o) => o.kind), [
        ScopeKind.me,
        ScopeKind.member,
        ScopeKind.house,
      ]);
      expect(kit.viewModel.scopeOptions[1].member, bia);
    });

    test('a_failure_to_load_the_profile_is_the_state_of_the_screen', () async {
      kit = HomeKit();
      kit.household.me = const Result.failure(NetworkFailure());

      await kit.viewModel.load();

      expect(kit.viewModel.profile, isA<UiError<HomeProfile>>());
      expect(kit.home.calls, isEmpty);
    });

    test('load_again_after_a_failure_recovers', () async {
      kit = HomeKit();
      kit.household.me = const Result.failure(NetworkFailure());
      await kit.viewModel.load();
      kit.household.me = const Result.success(ana);

      await kit.viewModel.load();

      expect(kit.viewModel.profile, isA<UiSuccess<HomeProfile>>());
    });

    test('if_the_people_list_fails_the_home_still_works_for_me', () async {
      kit = HomeKit();
      kit.household.users = const Result.failure(ServerUnavailableFailure());

      await kit.viewModel.load();

      final profile = (kit.viewModel.profile as UiSuccess<HomeProfile>).data;
      expect(profile.members, [ana]);
      expect(kit.viewModel.summary, isA<UiSuccess<Object?>>());
    });

    test('notifies_with_loading_first', () async {
      kit = HomeKit();
      final states = <UiState<HomeProfile>>[];
      kit.viewModel.addListener(() => states.add(kit.viewModel.profile));

      await kit.viewModel.load();

      expect(states.first, isA<UiLoading<HomeProfile>>());
      expect(states.last, isA<UiSuccess<HomeProfile>>());
    });
  });

  group('sections fail on their own', () {
    test('one_failing_section_leaves_the_others_working', () async {
      kit = HomeKit();
      kit.home.dailyResult = const Result.failure(ServerUnavailableFailure());

      await kit.viewModel.load();
      final vm = kit.viewModel;

      expect(vm.daily, isA<UiError<Object?>>());
      expect(vm.summary, isA<UiSuccess<Object?>>());
      expect(vm.upcoming, isA<UiSuccess<Object?>>());
    });

    test('retry_loads_only_that_section_again', () async {
      kit = HomeKit();
      kit.home.dailyResult = const Result.failure(ServerUnavailableFailure());
      await kit.viewModel.load();
      kit.home.calls.clear();
      kit.home.dailyResult = Result.success([]);

      await kit.viewModel.retry(HomeSection.daily);

      expect(kit.viewModel.daily, isA<UiSuccess<Object?>>());
      expect(kit.home.calls, hasLength(1));
      expect(kit.home.calls.single, startsWith('dailyExpenses'));
    });

    test('a_section_without_connection_turns_on_the_offline_strip', () async {
      kit = HomeKit();
      kit.home.topResult = const Result.failure(NetworkFailure());

      await kit.viewModel.load();

      expect(kit.viewModel.networkFailure, const NetworkFailure());
    });

    test('other_failures_do_not_turn_on_the_offline_strip', () async {
      kit = HomeKit();
      kit.home.topResult = const Result.failure(ServerUnavailableFailure());

      await kit.viewModel.load();

      expect(kit.viewModel.networkFailure, isNull);
    });
  });

  group('who appears', () {
    test('the_house_asks_without_a_person', () async {
      await loaded();

      await kit.viewModel.selectScope(const ScopeOption.house());

      expect(
        kit.home.calls.where((c) => c.startsWith('totalRevenues')).last,
        'totalRevenues 2026-11-01..2026-11-12 user=null',
      );
    });

    test('choosing_another_person_asks_for_that_person', () async {
      await loaded();

      await kit.viewModel.selectScope(const ScopeOption.person(bia));

      expect(
        kit.home.calls.where((c) => c.startsWith('totalRevenues')).last,
        'totalRevenues 2026-11-01..2026-11-12 user=m2',
      );
    });

    test('by_person_only_for_the_house_with_more_than_one_person', () async {
      await loaded();
      expect(kit.viewModel.showsByMember, isFalse);
      expect(kit.viewModel.byMember, isA<UiEmpty<Object?>>());

      await kit.viewModel.selectScope(const ScopeOption.house());

      expect(kit.viewModel.showsByMember, isTrue);
      expect(kit.viewModel.byMember, isA<UiSuccess<Object?>>());
    });

    test('by_person_asks_the_spending_of_each_person', () async {
      await loaded();
      kit.home.calls.clear();

      await kit.viewModel.selectScope(const ScopeOption.house());

      expect(
        kit.home.calls.where((c) => c.startsWith('totalExpenses')),
        containsAll([
          'totalExpenses 2026-11-01..2026-11-12 user=null',
          'totalExpenses 2026-11-01..2026-11-12 user=m1',
          'totalExpenses 2026-11-01..2026-11-12 user=m2',
        ]),
      );
    });

    test('a_house_of_one_person_has_no_by_person_card', () async {
      await loaded(users: const [ana]);

      await kit.viewModel.selectScope(const ScopeOption.house());

      expect(kit.viewModel.showsByMember, isFalse);
    });

    test('choosing_the_same_option_again_does_nothing', () async {
      await loaded();
      kit.home.calls.clear();

      await kit.viewModel.selectScope(ScopeOption.me(ana));

      expect(kit.home.calls, isEmpty);
    });

    test('three_people_make_five_options', () async {
      await loaded(users: const [ana, bia, caio]);

      expect(kit.viewModel.scopeOptions, hasLength(4));
    });
  });

  group('month', () {
    test('the_previous_month_is_whole', () async {
      await loaded();

      await kit.viewModel.goToPreviousMonth();

      expect(kit.viewModel.period.firstDay, DateTime(2026, 10));
      expect(
        kit.home.calls,
        contains('totalExpenses 2026-10-01..2026-10-31 user=m1'),
      );
      expect(
        kit.home.calls,
        contains('totalPlanned 2026-10-01..2026-10-31 EXPENSES user=m1'),
      );
    });

    test('going_back_and_forward_returns_to_the_current_month', () async {
      await loaded();

      await kit.viewModel.goToPreviousMonth();
      await kit.viewModel.goToNextMonth();

      expect(kit.viewModel.period.firstDay, DateTime(2026, 11));
      expect(kit.viewModel.lastClosedDay, DateTime(2026, 11, 12));
    });

    test('cannot_go_forward_from_the_current_month', () async {
      await loaded();
      kit.home.calls.clear();

      await kit.viewModel.goToNextMonth();

      expect(kit.viewModel.canGoNext, isFalse);
      expect(kit.home.calls, isEmpty);
    });

    test('cannot_go_back_more_than_eleven_months', () async {
      await loaded();

      for (var i = 0; i < 20; i++) {
        await kit.viewModel.goToPreviousMonth();
      }

      expect(kit.viewModel.period.firstDay, DateTime(2025, 12));
      expect(kit.viewModel.canGoPrevious, isFalse);
    });

    test('on_day_one_no_transaction_endpoint_is_called', () async {
      await loaded(now: DateTime(2026, 11, 1, 8));
      final calls = kit.home.calls;

      expect(
        calls.where(
          (c) =>
              c.startsWith('totalExpenses') ||
              c.startsWith('totalRevenues') ||
              c.startsWith('balance') ||
              c.startsWith('averageDailyExpenses') ||
              c.startsWith('dailyExpenses') ||
              c.startsWith('topExpenses'),
        ),
        isEmpty,
      );
      expect(calls.any((c) => c.startsWith('totalPlanned')), isTrue);
      expect(calls.any((c) => c.startsWith('upcomingEntries')), isTrue);
    });

    test('on_day_one_the_summary_is_zero_and_there_is_no_spending', () async {
      await loaded(now: DateTime(2026, 11, 1, 8));

      expect(kit.viewModel.summary, isA<UiSuccess<Object?>>());
      expect(kit.viewModel.hasSpending, isFalse);
      expect(kit.viewModel.lastClosedDay, isNull);
    });
  });

  group('spending details', () {
    test('there_is_spending_when_the_total_is_above_zero', () async {
      await loaded();

      expect(kit.viewModel.hasSpending, isTrue);
    });

    test('there_is_no_spending_when_the_total_is_zero', () async {
      kit = HomeKit();
      kit.home.totalExpensesResult = Result.success(dec('0.00'));

      await kit.viewModel.load();

      expect(kit.viewModel.hasSpending, isFalse);
    });
  });

  group('answers that arrive late', () {
    test('an_old_answer_does_not_overwrite_a_newer_one', () async {
      await loaded();
      // The answer for the house is held...
      kit.home.totalExpensesGate = Completer();
      final held = kit.home.totalExpensesGate!;
      final first = kit.viewModel.selectScope(const ScopeOption.house());
      // ...then the person chooses Bia, whose answer is immediate.
      kit.home.totalExpensesGate = null;
      kit.home.totalExpensesResult = Result.success(dec('222.00'));
      await kit.viewModel.selectScope(const ScopeOption.person(bia));

      // The held answer arrives late and must be thrown away.
      held.complete(Result.success(dec('999.00')));
      await first;

      final summary = kit.viewModel.summary as UiSuccess<SpendingSummary>;
      expect(summary.data.spent, dec('222.00'));
      expect(kit.viewModel.scope?.userId, 'm2');
    });
  });

  group('refresh', () {
    test('keeps_the_numbers_on_screen_while_it_loads', () async {
      await loaded();
      kit.home.totalExpensesGate = Completer();
      final held = kit.home.totalExpensesGate!;

      final refreshing = kit.viewModel.refresh();

      expect(kit.viewModel.summary, isA<UiSuccess<Object?>>());
      kit.home.totalExpensesGate = null;
      held.complete(Result.success(dec('50.00')));
      await refreshing;
      final summary = kit.viewModel.summary as UiSuccess<SpendingSummary>;
      expect(summary.data.spent, dec('50.00'));
    });

    test('without_a_profile_it_loads_everything', () async {
      kit = HomeKit();

      await kit.viewModel.refresh();

      expect(kit.viewModel.profile, isA<UiSuccess<HomeProfile>>());
    });
  });

  group('logout', () {
    test('forgets_the_token_and_closes_the_session', () async {
      await loaded();
      kit.session.onLoggedIn();

      await kit.viewModel.logout();

      expect(kit.auth.logouts, 1);
      expect(kit.session.isLoggedIn, isFalse);
    });
  });

  test('it_can_be_disposed_while_answers_are_on_the_way', () async {
    kit = HomeKit();
    final loading = kit.viewModel.load();

    kit.viewModel.dispose();

    await expectLater(loading, completes);
    // The tearDown disposes the kit: give it a fresh ViewModel.
    kit = HomeKit();
  });
}
