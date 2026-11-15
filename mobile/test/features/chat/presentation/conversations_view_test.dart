import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/chat/domain/usecases/get_conversations.dart';
import 'package:mobile/features/chat/presentation/viewmodels/conversations_view_model.dart';
import 'package:mobile/features/chat/presentation/views/conversations_view.dart';

import '../../../support/fake_chat_repository.dart';
import '../../../support/pump_app.dart';

void main() {
  late FakeChatRepository repository;
  final now = DateTime(2026, 11, 13, 10);

  setUp(() {
    repository = FakeChatRepository()
      ..conversations = [
        makeConversation(
          id: 'a',
          title: 'Gastos de novembro',
          contextTokens: 25000,
          lastMessageAt: DateTime(2026, 11, 13, 8),
        ),
        makeConversation(
          id: 'b',
          title: 'Conciliação',
          contextTokens: 50000,
          lastMessageAt: DateTime(2026, 11, 12, 20),
        ),
        makeConversation(id: 'c', title: '', createdAt: DateTime(2026, 11, 2)),
      ];
  });

  Future<void> pumpView(
    WidgetTester tester, {
    ValueChanged<String>? onSelected,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      ConversationsView(
        createViewModel: () => ConversationsViewModel(
          getConversations: GetConversations(repository),
        ),
        onSelected: onSelected,
        now: () => now,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists_conversations_with_title_relative_date_and_usage', (
    tester,
  ) async {
    await pumpView(tester);

    expect(find.text('Gastos de novembro'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Ontem'), findsOneWidget);
    expect(find.text('02/11'), findsOneWidget);
    expect(find.text('50% do limite'), findsOneWidget);
    expect(find.text('100% do limite'), findsOneWidget);
    expect(find.text('Conversa sem título'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
  });

  testWidgets('tapping_a_row_hands_over_the_conversation_id', (tester) async {
    String? picked;
    await pumpView(tester, onSelected: (id) => picked = id);

    await tester.tap(find.text('Conciliação'));

    expect(picked, 'b');
  });

  testWidgets('no_conversations_shows_the_empty_state', (tester) async {
    repository.conversations = [];
    await pumpView(tester);

    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
  });

  testWidgets('an_error_shows_retry_and_retry_loads_the_list', (tester) async {
    repository.listForced = const Result.failure(NetworkFailure());
    await pumpView(tester);
    expect(find.text('Tentar novamente'), findsOneWidget);

    repository.listForced = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Gastos de novembro'), findsOneWidget);
  });
}
