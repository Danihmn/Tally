import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/chat/domain/usecases/get_conversations.dart';
import 'package:mobile/features/chat/presentation/viewmodels/conversations_view_model.dart';

import '../../../support/fake_chat_repository.dart';

void main() {
  late FakeChatRepository repository;
  late ConversationsViewModel vm;

  setUp(() {
    repository = FakeChatRepository()
      ..conversations = [
        for (var i = 0; i < 45; i++) makeConversation(id: 'c$i', title: 'T$i'),
      ];
    vm = ConversationsViewModel(getConversations: GetConversations(repository));
  });
  tearDown(() => vm.dispose());

  test('load_shows_the_first_page_and_knows_there_is_more', () async {
    await vm.load();

    expect((vm.state as UiSuccess).data, hasLength(30));
    expect(vm.total, 45);
    expect(vm.hasMore, isTrue);
  });

  test('loadMore_appends_the_next_page_until_the_end', () async {
    await vm.load();
    await vm.loadMore();

    expect((vm.state as UiSuccess).data, hasLength(45));
    expect(vm.hasMore, isFalse);
  });

  test('no_conversations_is_the_empty_state', () async {
    repository.conversations = [];
    await vm.load();

    expect(vm.state, isA<UiEmpty<dynamic>>());
  });

  test('a_failure_is_the_error_state', () async {
    repository.listForced = const Result.failure(NetworkFailure());
    await vm.load();

    expect((vm.state as UiError).failure, const NetworkFailure());
  });
}
