import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

import '../../../support/fake_household_repository.dart';
import '../../../support/fakes.dart';

const ana = Member(id: 'm1', firstName: 'Ana', householdId: 'h1');
const bia = Member(id: 'm2', firstName: 'Bia', householdId: 'h1');
const caio = Member(id: 'm3', firstName: 'Caio', householdId: 'h1');

void main() {
  late FakeHouseholdRepository repository;
  late SessionExpiredNotifier notifier;
  late SessionController session;
  late HouseholdScopeController controller;

  setUp(() {
    repository = FakeHouseholdRepository(
      me: const Result<Member>.success(ana),
      users: const Result<List<Member>>.success([ana, bia]),
    );
    notifier = SessionExpiredNotifier();
    session = SessionController(
      tokenStore: SessionTokenStore(FakeSecureStorage()),
      expiredNotifier: notifier,
    );
    controller = HouseholdScopeController(
      getMe: GetMe(repository),
      getMembers: GetHouseholdMembers(repository),
      session: session,
    );
  });

  tearDown(() async {
    controller.dispose();
    session.dispose();
    await notifier.dispose();
  });

  group('loading', () {
    test('nothing_is_loaded_until_a_screen_asks', () {
      expect(controller.profile, isA<UiInitial<HouseholdProfile>>());
      expect(controller.scope, isNull);
      expect(controller.scopeOptions, isEmpty);
      expect(repository.meCalls, 0);
    });

    test('loads_me_and_the_people_of_the_house', () async {
      await controller.ensureLoaded();

      final profile = controller.profileData!;
      expect(profile.me, ana);
      expect(profile.members, [ana, bia]);
    });

    test('the_first_choice_is_me', () async {
      await controller.ensureLoaded();

      expect(controller.scope?.kind, ScopeKind.me);
      expect(controller.scope?.userId, 'm1');
    });

    test('the_options_are_me_the_others_and_the_house', () async {
      await controller.ensureLoaded();

      expect(controller.scopeOptions.map((o) => o.kind), [
        ScopeKind.me,
        ScopeKind.member,
        ScopeKind.house,
      ]);
      expect(controller.scopeOptions[1].member, bia);
      expect(controller.scopeOptions.last.userId, isNull);
    });

    test('with_three_people_there_are_four_options', () async {
      repository.users = const Result.success([ana, bia, caio]);

      await controller.ensureLoaded();

      expect(controller.scopeOptions, hasLength(4));
    });

    test('screens_that_ask_at_the_same_time_share_one_request', () async {
      await Future.wait([
        controller.ensureLoaded(),
        controller.ensureLoaded(),
        controller.ensureLoaded(),
      ]);

      expect(repository.meCalls, 1);
      expect(repository.usersCalls, 1);
    });

    test('asking_again_after_a_success_makes_no_request', () async {
      await controller.ensureLoaded();

      await controller.ensureLoaded();

      expect(repository.meCalls, 1);
    });

    test('if_the_people_list_fails_it_still_works_for_me', () async {
      repository.users = const Result.failure(ServerUnavailableFailure());

      await controller.ensureLoaded();

      expect(controller.profileData?.members, [ana]);
    });

    test(
      'a_failure_to_load_me_is_the_state_and_asking_again_retries',
      () async {
        repository.me = const Result.failure(NetworkFailure());
        await controller.ensureLoaded();
        expect(controller.profile, isA<UiError<HouseholdProfile>>());

        repository.me = const Result.success(ana);
        await controller.ensureLoaded();

        expect(controller.profile, isA<UiSuccess<HouseholdProfile>>());
        expect(repository.meCalls, 2);
      },
    );

    test('reload_asks_the_api_again', () async {
      await controller.ensureLoaded();

      await controller.reload();

      expect(repository.meCalls, 2);
    });

    test('listeners_hear_the_loading_and_then_the_result', () async {
      final states = <UiState<HouseholdProfile>>[];
      controller.addListener(() => states.add(controller.profile));

      await controller.ensureLoaded();

      expect(states.first, isA<UiLoading<HouseholdProfile>>());
      expect(states.last, isA<UiSuccess<HouseholdProfile>>());
    });
  });

  group('who appears', () {
    test(
      'choosing_another_option_changes_the_scope_and_tells_the_listeners',
      () async {
        await controller.ensureLoaded();
        var calls = 0;
        controller.addListener(() => calls++);

        controller.select(const ScopeOption.house());

        expect(controller.scope?.kind, ScopeKind.house);
        expect(controller.scope?.userId, isNull);
        expect(calls, 1);
      },
    );

    test('choosing_another_person_gives_that_person_id', () async {
      await controller.ensureLoaded();

      controller.select(const ScopeOption.person(bia));

      expect(controller.scope?.userId, 'm2');
    });

    test('choosing_the_same_option_again_tells_nobody', () async {
      await controller.ensureLoaded();
      var calls = 0;
      controller.addListener(() => calls++);

      controller.select(ScopeOption.me(ana));

      expect(calls, 0);
    });

    test('nothing_can_be_chosen_before_the_profile_is_loaded', () {
      var calls = 0;
      controller.addListener(() => calls++);

      controller.select(const ScopeOption.house());

      expect(controller.scope, isNull);
      expect(calls, 0);
    });
  });

  group('reset', () {
    test('logging_out_forgets_the_profile_and_the_choice', () async {
      await controller.ensureLoaded();
      controller.select(const ScopeOption.house());

      session.onLoggedOut();

      expect(controller.profile, isA<UiInitial<HouseholdProfile>>());
      expect(controller.scope, isNull);
    });

    test('the_next_login_starts_with_me_again', () async {
      await controller.ensureLoaded();
      controller.select(const ScopeOption.house());
      session.onLoggedOut();

      session.onLoggedIn();
      await controller.ensureLoaded();

      expect(controller.scope?.kind, ScopeKind.me);
      expect(repository.meCalls, 2);
    });

    test('logging_in_does_not_reset_a_loaded_profile', () async {
      await controller.ensureLoaded();

      session.onLoggedIn();

      expect(controller.profile, isA<UiSuccess<HouseholdProfile>>());
    });

    test('a_load_that_ends_after_a_reset_is_thrown_away', () async {
      repository.meGate = Completer();
      final loading = controller.ensureLoaded();

      session.onLoggedOut();
      repository.meGate!.complete(const Result.success(ana));
      await loading;

      expect(controller.profile, isA<UiInitial<HouseholdProfile>>());
    });
  });

  group('refreshMembers', () {
    test('a_new_person_shows_up_without_going_back_to_loading', () async {
      await controller.ensureLoaded();
      final states = <UiState<HouseholdProfile>>[];
      controller.addListener(() => states.add(controller.profile));
      repository.users = const Result.success([ana, bia, caio]);

      await controller.refreshMembers();

      expect(controller.profileData?.members, [ana, bia, caio]);
      expect(states.every((s) => s is UiSuccess<HouseholdProfile>), isTrue);
    });

    test('the_chosen_person_is_kept_with_their_new_data', () async {
      await controller.ensureLoaded();
      controller.select(ScopeOption.person(bia));
      const renamed = Member(
        id: 'm2',
        firstName: 'Bia',
        surname: 'Bibi',
        householdId: 'h1',
      );
      repository.users = const Result.success([ana, renamed]);

      await controller.refreshMembers();

      expect(controller.scope, ScopeOption.person(renamed));
      expect(controller.scope?.member?.displayName, 'Bibi');
    });

    test('the_house_choice_stays_the_house', () async {
      await controller.ensureLoaded();
      controller.select(const ScopeOption.house());

      await controller.refreshMembers();

      expect(controller.scope, const ScopeOption.house());
    });

    test('a_person_that_left_the_list_sends_the_choice_back_to_me', () async {
      await controller.ensureLoaded();
      controller.select(ScopeOption.person(bia));
      repository.users = const Result.success([ana]);

      await controller.refreshMembers();

      expect(controller.scope, ScopeOption.me(ana));
    });

    test('my_own_edit_updates_me', () async {
      await controller.ensureLoaded();
      const edited = Member(
        id: 'm1',
        firstName: 'Ana',
        surname: 'Aninha',
        householdId: 'h1',
      );
      repository.me = const Result.success(edited);
      repository.users = const Result.success([edited, bia]);

      await controller.refreshMembers();

      expect(controller.profileData?.me.displayName, 'Aninha');
      expect(controller.scope, ScopeOption.me(edited));
    });

    test('a_failure_keeps_what_was_there', () async {
      await controller.ensureLoaded();
      repository.users = const Result.failure(NetworkFailure());

      await controller.refreshMembers();

      expect(controller.profileData?.members, [ana, bia]);
    });

    test('without_a_loaded_profile_it_loads_it', () async {
      await controller.refreshMembers();

      expect(controller.profileData?.me, ana);
    });
  });

  test('it_can_be_disposed_while_the_load_runs', () async {
    repository.meGate = Completer();
    final loading = controller.ensureLoaded();

    controller.dispose();
    repository.meGate!.complete(const Result.success(ana));

    await expectLater(loading, completes);
    // The tearDown disposes the controller again: give it a fresh one.
    controller = HouseholdScopeController(
      getMe: GetMe(repository),
      getMembers: GetHouseholdMembers(repository),
      session: session,
    );
  });
}
