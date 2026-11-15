import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/chat_stream_event.dart';
import 'package:mobile/features/chat/domain/usecases/get_conversation.dart';
import 'package:mobile/features/chat/domain/usecases/send_chat_message.dart';
import 'package:mobile/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:mobile/features/chat/presentation/views/chat_view.dart';
import 'package:mobile/features/chat/presentation/widgets/chat_bubbles.dart';

import '../../../support/fake_chat_repository.dart';
import '../../../support/pump_app.dart';

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

  Future<void> pumpView(
    WidgetTester tester, {
    Future<String?> Function()? onOpenHistory,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      ChatView(createViewModel: () => vm, onOpenHistory: onOpenHistory),
    );
    await tester.pump();
  }

  /// The fake's streams run in the real zone: let them deliver, then redraw.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();
  }

  void openWith({int context = 1000, int limit = 50000}) {
    repository.detail = Result.success(
      ConversationDetail(
        conversation: makeConversation(
          contextTokens: context,
          tokenLimit: limit,
        ),
        messages: [
          makeMessage('m1', ChatRole.user, 'Quanto gastamos?'),
          makeMessage('m2', ChatRole.assistant, 'Gastamos **R\$ 10,00**.'),
        ],
      ),
    );
  }

  group('empty state', () {
    testWidgets('shows_the_invitation_the_suggestions_and_the_captions', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Pergunte sobre o dinheiro da casa'), findsOneWidget);
      expect(find.text('Quanto gastei este mês?'), findsOneWidget);
      expect(
        find.text('O Tally IA pode errar. Confira os valores importantes.'),
        findsOneWidget,
      );
      expect(find.textContaining('só neste aparelho'), findsNothing);
      expect(
        find.textContaining('histórico das conversas fica salvo'),
        findsOneWidget,
      );
      expect(find.byTooltip('Nova conversa'), findsOneWidget);
      expect(find.byTooltip('Histórico de conversas'), findsOneWidget);
    });

    testWidgets('tapping_a_suggestion_sends_it', (tester) async {
      repository.answer(normalAnswer(['Resposta']));
      await pumpView(tester);

      await tester.tap(find.text('Quanto gastei este mês?'));
      await tester.pump();
      await tester.pump();

      expect(repository.sendCalls.single.message, 'Quanto gastei este mês?');
      expect(find.byType(UserBubble), findsOneWidget);
    });
  });

  group('conversation', () {
    testWidgets('typing_indicator_then_markdown_answer_with_a_table', (
      tester,
    ) async {
      final stream = repository.enqueue();
      await pumpView(tester);

      await type(tester, 'Gastos por categoria');
      await tapSend(tester);

      expect(find.byType(UserBubble), findsOneWidget);
      expect(find.text('Gastos por categoria'), findsOneWidget);
      expect(find.byType(TypingBubble), findsOneWidget);
      expect(find.text('Digitando… consultando seus dados'), findsOneWidget);

      stream.add(
        const Result.success(
          ChatMeta(conversationId: 'c1', title: 'Gastos', isNew: true),
        ),
      );
      stream.add(
        const Result.success(
          ChatToken(
            'Total **R\$ 10,00**\n\n| Categoria | Valor |\n| --- | --- |\n',
          ),
        ),
      );
      stream.add(const Result.success(ChatToken('| Mercado | 10,00 |')));
      stream.add(
        const Result.success(ChatDone(contextTokens: 100, tokenLimit: 50000)),
      );
      await stream.close();
      await tester.pump();
      await tester.pump();

      expect(find.byType(TypingBubble), findsNothing);
      expect(find.byType(AssistantBubble), findsOneWidget);
      expect(find.text('Mercado', findRichText: true), findsOneWidget);
      final cell = find.text('10,00', findRichText: true);
      expect(cell, findsOneWidget);
      final style = tester.widget<DefaultTextStyle>(
        find.ancestor(of: cell, matching: find.byType(DefaultTextStyle)).first,
      );
      expect(style.textAlign, TextAlign.right);
    });

    testWidgets('a_failure_shows_an_error_bubble_and_retry_sends_again', (
      tester,
    ) async {
      repository.fail(const NetworkFailure());
      await pumpView(tester);
      await type(tester, 'Oi');
      await tapSend(tester);
      await settle(tester);

      debugPrint('DBG ${vm.failure} ${vm.isStreaming} ${vm.messages.length}');
      expect(find.byType(ErrorBubble), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(find.byType(UserBubble), findsOneWidget);

      repository.answer(normalAnswer(['Certo']));
      await tester.tap(find.text('Tentar de novo'));
      await settle(tester);

      expect(find.byType(ErrorBubble), findsNothing);
      expect(find.text('Certo', findRichText: true), findsOneWidget);
      expect(repository.sendCalls.map((c) => c.message), ['Oi', 'Oi']);
    });

    testWidgets('the_counter_appears_at_1700_characters', (tester) async {
      await pumpView(tester);

      await type(tester, 'a' * 1699);
      expect(find.text('1699/2000'), findsNothing);
      await type(tester, 'a' * 1700);
      expect(find.text('1700/2000'), findsOneWidget);
    });

    testWidgets('sending_is_off_for_empty_text', (tester) async {
      await pumpView(tester);

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('limit', () {
    testWidgets('at_80_percent_a_banner_warns_and_the_composer_stays', (
      tester,
    ) async {
      openWith(context: 41000);
      var opened = false;
      await pumpView(
        tester,
        onOpenHistory: () async {
          opened = true;
          return 'c1';
        },
      );

      await tester.tap(find.byTooltip('Histórico de conversas'));
      await tester.pump();
      await tester.pump();

      expect(opened, isTrue);
      expect(find.textContaining('chegando ao limite'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Conversa cheia'), findsNothing);
    });

    testWidgets('below_80_percent_there_is_no_banner', (tester) async {
      openWith(context: 1000);
      await pumpView(tester, onOpenHistory: () async => 'c1');
      await tester.tap(find.byTooltip('Histórico de conversas'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('chegando ao limite'), findsNothing);
    });

    testWidgets(
      'at_100_percent_the_composer_is_replaced_and_new_conversation_resets',
      (tester) async {
        openWith(context: 50000);
        await pumpView(tester, onOpenHistory: () async => 'c1');
        await tester.tap(find.byTooltip('Histórico de conversas'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Conversa cheia'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Iniciar nova conversa'), findsOneWidget);

        await tester.tap(find.text('Iniciar nova conversa'));
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Conversa cheia'), findsNothing);
        expect(find.text('Pergunte sobre o dinheiro da casa'), findsOneWidget);
      },
    );
  });

  group('history', () {
    testWidgets('picking_a_conversation_loads_its_messages_to_continue', (
      tester,
    ) async {
      openWith();
      await pumpView(tester, onOpenHistory: () async => 'c1');

      await tester.tap(find.byTooltip('Histórico de conversas'));
      await tester.pump();
      await tester.pump();

      expect(repository.getCalls, ['c1']);
      expect(find.text('Quanto gastamos?'), findsOneWidget);
      expect(
        find.text('Gastamos R\$ 10,00.', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('closing_the_history_without_a_pick_changes_nothing', (
      tester,
    ) async {
      await pumpView(tester, onOpenHistory: () async => null);

      await tester.tap(find.byTooltip('Histórico de conversas'));
      await tester.pump();

      expect(repository.getCalls, isEmpty);
      expect(find.text('Pergunte sobre o dinheiro da casa'), findsOneWidget);
    });

    testWidgets('a_failed_open_shows_retry', (tester) async {
      repository.detail = const Result.failure(NetworkFailure());
      await pumpView(tester, onOpenHistory: () async => 'c1');
      await tester.tap(find.byTooltip('Histórico de conversas'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Tentar novamente'), findsOneWidget);

      openWith();
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Quanto gastamos?'), findsOneWidget);
    });

    testWidgets('new_conversation_clears_the_chat', (tester) async {
      openWith();
      await pumpView(tester, onOpenHistory: () async => 'c1');
      await tester.tap(find.byTooltip('Histórico de conversas'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byTooltip('Nova conversa'));
      await tester.pump();

      expect(find.text('Quanto gastamos?'), findsNothing);
      expect(find.text('Pergunte sobre o dinheiro da casa'), findsOneWidget);
    });
  });
}
