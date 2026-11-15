import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/chat_stream_event.dart';
import 'package:mobile/features/chat/domain/usecases/get_conversation.dart';
import 'package:mobile/features/chat/domain/usecases/send_chat_message.dart';
import 'package:mobile/features/chat/presentation/viewmodels/chat_view_model.dart';

import '../../../support/fake_chat_repository.dart';

void main() {
  late FakeChatRepository repository;
  late ChatViewModel vm;

  setUp(() {
    repository = FakeChatRepository();
    vm = ChatViewModel(
      sendMessage: SendChatMessage(repository),
      getConversation: GetConversation(repository),
    );
  });
  tearDown(() => vm.dispose());

  String last() => vm.messages.last.content;

  group('send', () {
    test('tokens_are_appended_to_the_answer_as_they_arrive', () async {
      final stream = repository.enqueue();
      final done = vm.send('  Quanto gastamos?  ');
      await pumpEventQueue();

      expect(vm.isStreaming, isTrue);
      expect(vm.isTyping, isTrue);
      expect(vm.messages.first.content, 'Quanto gastamos?');

      stream.add(
        const Result.success(
          ChatMeta(conversationId: 'c1', title: 'Gastos', isNew: true),
        ),
      );
      await pumpEventQueue();
      expect(vm.isTyping, isTrue);
      expect(vm.title, 'Gastos');

      stream.add(const Result.success(ChatToken('Olá ')));
      stream.add(const Result.success(ChatToken('**mundo**')));
      await pumpEventQueue();
      expect(last(), 'Olá **mundo**');
      expect(vm.isTyping, isFalse);

      stream.add(
        const Result.success(ChatDone(contextTokens: 900, tokenLimit: 50000)),
      );
      await stream.close();
      await done;

      expect(vm.isStreaming, isFalse);
      expect(vm.messages.map((m) => m.role), [
        ChatRole.user,
        ChatRole.assistant,
      ]);
      expect(vm.usage.contextTokens, 900);
      expect(vm.conversationId, 'c1');
    });

    test(
      'the_first_message_starts_a_conversation_and_the_next_continues',
      () async {
        repository.answer(normalAnswer(['a']));
        await vm.send('um');
        repository.answer(normalAnswer(['b']));
        await vm.send('dois');

        expect(repository.sendCalls.map((c) => c.conversationId), [null, 'c1']);
        expect(vm.messages, hasLength(4));
      },
    );

    test('empty_too_long_and_while_streaming_messages_are_ignored', () async {
      await vm.send('   ');
      await vm.send('x' * (ChatViewModel.maxMessageLength + 1));
      expect(repository.sendCalls, isEmpty);

      final stream = repository.enqueue();
      final first = vm.send('oi');
      await pumpEventQueue();
      await vm.send('de novo');
      expect(repository.sendCalls, hasLength(1));

      await stream.close();
      await first;
    });
  });

  group('limit', () {
    Future<void> sendWithContext(int context, {int limit = 100}) async {
      repository.answer(normalAnswer(['x'], context: context, limit: limit));
      await vm.send('oi');
    }

    test('below_80_percent_there_is_no_warning', () async {
      await sendWithContext(79);

      expect(vm.isWarning, isFalse);
      expect(vm.isBlocked, isFalse);
    });

    test('at_80_percent_it_warns_but_still_accepts_messages', () async {
      await sendWithContext(80);

      expect(vm.isWarning, isTrue);
      expect(vm.isBlocked, isFalse);
      repository.answer(normalAnswer(['y']));
      await vm.send('mais uma');
      expect(repository.sendCalls, hasLength(2));
    });

    test('at_100_percent_it_is_blocked_and_refuses_to_send', () async {
      await sendWithContext(100);

      expect(vm.isBlocked, isTrue);
      expect(vm.isWarning, isFalse);
      await vm.send('mais uma');
      expect(repository.sendCalls, hasLength(1));
    });

    test('a_409_blocks_the_conversation_and_removes_the_question', () async {
      repository.fail(const ConversationFullFailure());
      await vm.send('oi');

      expect(vm.isBlocked, isTrue);
      expect(vm.messages, isEmpty);
      expect(vm.failure, isNull);
    });

    test('starting_a_new_conversation_unblocks', () async {
      await sendWithContext(100);
      vm.startNew();

      expect(vm.isBlocked, isFalse);
      expect(vm.messages, isEmpty);
      expect(vm.conversationId, isNull);
    });
  });

  group('failure and retry', () {
    test(
      'a_failure_keeps_the_question_drops_the_half_answer_and_shows_failure',
      () async {
        final stream = repository.enqueue();
        final run = vm.send('oi');
        await pumpEventQueue();
        stream.add(const Result.success(ChatToken('meio')));
        stream.add(const Result.failure(NetworkFailure()));
        await stream.close();
        await run;

        expect(vm.failure, const NetworkFailure());
        expect(vm.isStreaming, isFalse);
        expect(vm.messages.map((m) => m.content), ['oi']);
      },
    );

    test('an_error_event_is_a_failure', () async {
      repository.answer([
        const ChatMeta(conversationId: 'c1', title: 'T', isNew: true),
        const ChatStreamError('agent_failed'),
      ]);
      await vm.send('oi');

      expect(vm.failure, const ServerUnavailableFailure());
    });

    test('a_stream_that_ends_without_done_is_a_failure', () async {
      repository.answer([const ChatToken('meio')]);
      await vm.send('oi');

      expect(vm.failure, isNotNull);
      expect(vm.messages, hasLength(1));
    });

    test(
      'retry_asks_the_same_question_again_without_a_second_bubble',
      () async {
        repository.fail(const NetworkFailure());
        await vm.send('oi');
        repository.answer(normalAnswer(['resposta']));
        await vm.retry();

        expect(repository.sendCalls.map((c) => c.message), ['oi', 'oi']);
        expect(vm.failure, isNull);
        expect(vm.messages.map((m) => m.content), ['oi', 'resposta']);
      },
    );

    test('retry_does_nothing_without_a_failure', () async {
      await vm.retry();

      expect(repository.sendCalls, isEmpty);
    });
  });

  group('open and startNew', () {
    test('open_loads_the_history_and_the_usage_then_continues_the_same_conversation', () async {
      repository.detail = Result.success(
        ConversationDetail(
          conversation: makeConversation(
            id: 'c7',
            title: 'Antiga',
            contextTokens: 45000,
          ),
          messages: [
            makeMessage('m1', ChatRole.user, 'Oi'),
            makeMessage('m2', ChatRole.assistant, 'Olá'),
          ],
        ),
      );
      await vm.open('c7');

      expect(vm.messages.map((m) => m.content), ['Oi', 'Olá']);
      expect(vm.title, 'Antiga');
      expect(vm.isWarning, isTrue);

      repository.answer(normalAnswer(['ok'], id: 'c7', isNew: false));
      await vm.send('continua');
      expect(repository.sendCalls.single.conversationId, 'c7');
    });

    test('opening_a_full_conversation_blocks_it', () async {
      repository.detail = Result.success(
        ConversationDetail(
          conversation: makeConversation(contextTokens: 50000),
          messages: const [],
        ),
      );
      await vm.open('c1');

      expect(vm.isBlocked, isTrue);
    });

    test('a_failed_open_exposes_the_failure_and_reopen_tries_again', () async {
      repository.detail = const Result.failure(NetworkFailure());
      await vm.open('c1');
      expect(vm.historyFailure, const NetworkFailure());

      repository.detail = Result.success(
        ConversationDetail(
          conversation: makeConversation(),
          messages: [makeMessage('m1', ChatRole.user, 'Oi')],
        ),
      );
      await vm.reopen();

      expect(vm.historyFailure, isNull);
      expect(vm.messages, hasLength(1));
      expect(repository.getCalls, ['c1', 'c1']);
    });

    test('startNew_during_a_stream_ignores_what_arrives_later', () async {
      final stream = repository.enqueue();
      final run = vm.send('oi');
      await pumpEventQueue();
      vm.startNew();
      stream.add(const Result.success(ChatToken('tarde')));
      await stream.close();
      await run;

      expect(vm.messages, isEmpty);
      expect(vm.isStreaming, isFalse);
    });
  });
}
