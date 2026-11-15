import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/views/user_detail_view.dart';

import '../../../support/pump_app.dart';
import '../../../support/users_kit.dart';

void main() {
  late UsersKit kit;

  setUp(() => kit = UsersKit());
  tearDown(() => kit.dispose());

  Future<void> pumpDetail(WidgetTester tester, {Member? member = bia}) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      UserDetailView(createViewModel: () => kit.viewModel, member: member),
    );
    await tester.pumpAndSettle();
  }

  Finder field(int index) => find.byType(TextField).at(index);

  const goodId = '11111111-2222-3333-4444-555555555555';

  Future<void> openCredentials(WidgetTester tester) async {
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Credenciais da Pluggy'),
    );
    await tester.pumpAndSettle();
  }

  group('UserDetailView', () {
    testWidgets('shows_the_data_of_the_person', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Usuário'), findsOneWidget);
      expect(find.text('Bia Lima'), findsOneWidget);
      expect(find.text('bia@casa.com'), findsOneWidget);
      expect(find.text('Lima'), findsOneWidget);
      // No nickname yet.
      expect(find.text('Não informado'), findsOneWidget);
    });

    testWidgets('a_person_handed_over_without_data_says_so', (tester) async {
      await pumpDetail(tester, member: null);

      expect(find.text('Editar dados'), findsNothing);
    });

    testWidgets('editing_starts_with_the_current_values', (tester) async {
      await pumpDetail(tester, member: aninha);

      await tester.tap(find.text('Editar dados'));
      await tester.pumpAndSettle();

      expect(find.text('Editar usuário'), findsOneWidget);
      final texts = [
        for (var i = 0; i < 4; i++)
          tester.widget<TextField>(field(i)).controller!.text,
      ];
      expect(texts, ['Ana', 'Souza', 'Aninha', 'ana@casa.com']);
    });

    testWidgets('an_edit_is_sent_and_the_screen_shows_the_new_data', (
      tester,
    ) async {
      await pumpDetail(tester);
      const renamed = Member(
        id: 'm2',
        firstName: 'Bia',
        lastName: 'Lima',
        surname: 'Bibi',
        email: 'bia@casa.com',
        householdId: 'h1',
      );
      kit.household.users = const Result.success([aninha, renamed]);

      await tester.tap(find.text('Editar dados'));
      await tester.pumpAndSettle();
      await tester.enterText(field(2), 'Bibi');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final (id, changes) = kit.household.updated.single;
      expect((id, changes.firstName, changes.surname), ('m2', 'Bia', 'Bibi'));
      expect(find.text('Dados salvos.'), findsOneWidget);
      expect(find.text('Bibi'), findsWidgets);
      expect(find.text('Editar usuário'), findsNothing);
    });

    testWidgets('clearing_the_nickname_sends_null', (tester) async {
      await pumpDetail(tester, member: aninha);

      await tester.tap(find.text('Editar dados'));
      await tester.pumpAndSettle();
      await tester.enterText(field(2), '');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(kit.household.updated.single.$2.surname, isNull);
    });

    testWidgets('an_email_that_is_taken_keeps_the_edit_open_with_a_message', (
      tester,
    ) async {
      await pumpDetail(tester);
      kit.household.updateResult = const Result.failure(
        EmailAlreadyExistsFailure(),
      );

      await tester.tap(find.text('Editar dados'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Já existe um usuário com esse e-mail.'),
        findsOneWidget,
      );
      expect(find.text('Editar usuário'), findsOneWidget);
    });

    testWidgets('the_credentials_have_a_sheet_of_their_own_with_two_fields', (
      tester,
    ) async {
      await pumpDetail(tester);

      await openCredentials(tester);

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Client ID'), findsOneWidget);
      expect(find.text('Client Secret'), findsOneWidget);
      expect(find.textContaining('portal da Pluggy'), findsOneWidget);
      expect(find.textContaining('não são exibidas'), findsOneWidget);
      expect(tester.widget<TextField>(field(1)).obscureText, isTrue);
    });

    testWidgets('saving_the_credentials_asks_for_confirmation_first', (
      tester,
    ) async {
      await pumpDetail(tester);
      await openCredentials(tester);
      await tester.enterText(field(0), goodId);
      await tester.enterText(field(1), 's3cr3t');

      await tester.tap(find.text('Salvar credenciais'));
      await tester.pumpAndSettle();

      expect(find.text('Alterar as credenciais?'), findsOneWidget);
      expect(find.textContaining('funcionar mal'), findsOneWidget);
      expect(kit.household.credentialsSent, isEmpty);
    });

    testWidgets('cancelling_the_warning_sends_nothing_and_keeps_the_sheet', (
      tester,
    ) async {
      await pumpDetail(tester);
      await openCredentials(tester);
      await tester.enterText(field(0), goodId);
      await tester.enterText(field(1), 's3cr3t');
      await tester.tap(find.text('Salvar credenciais'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(kit.household.credentialsSent, isEmpty);
      expect(find.text('Salvar credenciais'), findsOneWidget);
    });

    testWidgets('confirming_sends_the_credentials_and_closes_the_sheet', (
      tester,
    ) async {
      await pumpDetail(tester);
      await openCredentials(tester);
      await tester.enterText(field(0), goodId);
      await tester.enterText(field(1), 's3cr3t');
      await tester.tap(find.text('Salvar credenciais'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alterar credenciais'));
      await tester.pumpAndSettle();

      final (id, credentials) = kit.household.credentialsSent.single;
      expect(
        (id, credentials.clientId, credentials.clientSecret),
        ('m2', goodId, 's3cr3t'),
      );
      expect(find.text('Credenciais atualizadas.'), findsOneWidget);
      expect(find.text('Salvar credenciais'), findsNothing);
    });

    testWidgets('an_invalid_client_id_shows_an_error_and_no_warning', (
      tester,
    ) async {
      await pumpDetail(tester);
      await openCredentials(tester);
      await tester.enterText(field(0), 'not-a-uuid');
      await tester.enterText(field(1), 's3cr3t');

      await tester.tap(find.text('Salvar credenciais'));
      await tester.pumpAndSettle();

      expect(find.textContaining('formato UUID'), findsOneWidget);
      expect(find.text('Alterar as credenciais?'), findsNothing);
      expect(kit.household.credentialsSent, isEmpty);
    });

    testWidgets('a_failed_save_keeps_the_sheet_with_a_message', (tester) async {
      await pumpDetail(tester);
      kit.household.credentialsResult = const Result.failure(
        ServerUnavailableFailure(),
      );
      await openCredentials(tester);
      await tester.enterText(field(0), goodId);
      await tester.enterText(field(1), 's3cr3t');
      await tester.tap(find.text('Salvar credenciais'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alterar credenciais'));
      await tester.pumpAndSettle();

      expect(find.text('Salvar credenciais'), findsOneWidget);
      expect(find.text('Credenciais atualizadas.'), findsNothing);
    });
  });
}
