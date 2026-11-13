import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/widgets/async_state_view.dart';
import 'package:mobile/core/widgets/skeleton.dart';

import '../../support/pump_app.dart';

Widget _view(UiState<List<String>> state, {VoidCallback? onRetry}) =>
    AsyncStateView<List<String>>(
      state: state,
      onRetry: onRetry ?? () {},
      builder: (context, data) => Text('itens: ${data.join(',')}'),
    );

void main() {
  group('AsyncStateView', () {
    testWidgets('shows_a_skeleton_while_loading', (tester) async {
      await pumpApp(tester, _view(const UiLoading()));
      expect(find.byType(SkeletonList), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows_the_content_on_success', (tester) async {
      await pumpApp(tester, _view(const UiSuccess(['a', 'b'])));
      expect(find.text('itens: a,b'), findsOneWidget);
    });

    testWidgets('shows_the_empty_message_when_empty', (tester) async {
      await pumpApp(tester, _view(const UiEmpty()));
      expect(find.text('Nada por aqui ainda'), findsOneWidget);
    });

    testWidgets('shows_a_portuguese_message_and_retries_on_error', (
      tester,
    ) async {
      var retries = 0;
      await pumpApp(
        tester,
        _view(
          const UiError(ServerUnavailableFailure()),
          onRetry: () => retries++,
        ),
      );
      expect(
        find.text('Serviço indisponível. Tente novamente em instantes.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tentar novamente'));
      expect(retries, 1);
    });

    testWidgets('a_network_error_says_there_is_no_connection', (tester) async {
      await pumpApp(tester, _view(const UiError(NetworkFailure())));
      expect(find.textContaining('Sem conexão'), findsOneWidget);
    });
  });
}
