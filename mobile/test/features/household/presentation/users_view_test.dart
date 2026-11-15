import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/views/users_view.dart';

import '../../../support/pump_app.dart';
import '../../../support/users_kit.dart';

void main() {
  late UsersKit kit;
  Member? opened;

  setUp(() {
    kit = UsersKit();
    opened = null;
  });
  tearDown(() => kit.dispose());

  Future<void> pumpUsers(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      UsersView(
        createViewModel: () => kit.viewModel,
        onOpenUser: (member) => opened = member,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(int index) => find.byType(TextField).at(index);

  Future<void> fillNewUser(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Novo usuário'));
    await tester.pumpAndSettle();
    await tester.enterText(field(0), 'Carla');
    await tester.enterText(field(2), 'Cacá');
    await tester.enterText(field(3), 'carla@casa.com');
    await tester.enterText(field(4), 'segredo123');
    await tester.enterText(field(5), '11111111-2222-3333-4444-555555555555');
    await tester.enterText(field(6), 's3cr3t');
  }

  group('UsersView', () {
    testWidgets('lists_the_people_by_nickname_with_me_marked', (tester) async {
      await pumpUsers(tester);

      expect(find.text('Usuários'), findsOneWidget);
      expect(find.text('Aninha (você)'), findsOneWidget);
      expect(find.text('Bia'), findsOneWidget);
      expect(find.textContaining('Ana Souza'), findsOneWidget);
      expect(find.textContaining('bia@casa.com'), findsOneWidget);
      // The first name of someone with a nickname is not the title.
      expect(find.text('Ana (você)'), findsNothing);
    });

    testWidgets('there_is_no_way_to_delete_a_person', (tester) async {
      await pumpUsers(tester);

      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.textContaining('Excluir'), findsNothing);
    });

    testWidgets('tapping_a_person_opens_their_details', (tester) async {
      await pumpUsers(tester);

      await tester.tap(find.text('Bia'));

      expect(opened, bia);
    });

    testWidgets('a_failed_load_shows_the_error_and_retry_works', (
      tester,
    ) async {
      kit.household.me = const Result.failure(NetworkFailure());
      await pumpUsers(tester);
      expect(find.text('Tentar novamente'), findsOneWidget);

      kit.household.me = const Result.success(aninha);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Aninha (você)'), findsOneWidget);
    });

    testWidgets('a_new_person_is_created_and_shows_up_in_the_list', (
      tester,
    ) async {
      await pumpUsers(tester);
      const carla = Member(
        id: 'm3',
        firstName: 'Carla',
        surname: 'Cacá',
        email: 'carla@casa.com',
        householdId: 'h1',
      );
      kit.household.users = const Result.success([aninha, bia, carla]);

      await fillNewUser(tester);
      await tester.tap(find.text('Criar usuário'));
      await tester.pumpAndSettle();

      final sent = kit.household.created.single;
      expect(
        (sent.firstName, sent.surname, sent.email, sent.password),
        ('Carla', 'Cacá', 'carla@casa.com', 'segredo123'),
      );
      expect(sent.pluggyClientId, '11111111-2222-3333-4444-555555555555');
      expect(sent.pluggyClientSecret, 's3cr3t');
      expect(find.text('Usuário criado.'), findsOneWidget);
      expect(find.text('Cacá'), findsOneWidget);
      expect(find.text('Criar usuário'), findsNothing);
    });

    testWidgets('the_new_user_form_tells_where_to_find_the_credentials', (
      tester,
    ) async {
      await pumpUsers(tester);

      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Novo usuário'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('portal da Pluggy'), findsOneWidget);
      expect(find.text('Client ID'), findsOneWidget);
      expect(find.text('Client Secret'), findsOneWidget);
    });

    testWidgets('the_secret_and_the_password_are_hidden_while_typing', (
      tester,
    ) async {
      await pumpUsers(tester);
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Novo usuário'),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(field(4)).obscureText, isTrue);
      expect(tester.widget<TextField>(field(6)).obscureText, isTrue);
      expect(tester.widget<TextField>(field(5)).obscureText, isFalse);
    });

    testWidgets('a_wrong_form_shows_the_errors_and_sends_nothing', (
      tester,
    ) async {
      await pumpUsers(tester);
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Novo usuário'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar usuário'));
      await tester.pumpAndSettle();

      expect(find.text('Preencha este campo.'), findsWidgets);
      expect(kit.household.created, isEmpty);
    });

    testWidgets('an_email_that_is_taken_keeps_the_sheet_open_with_a_message', (
      tester,
    ) async {
      await pumpUsers(tester);
      kit.household.createResult = const Result.failure(
        EmailAlreadyExistsFailure(),
      );

      await fillNewUser(tester);
      await tester.tap(find.text('Criar usuário'));
      await tester.pumpAndSettle();

      expect(
        find.text('Já existe um usuário com esse e-mail.'),
        findsOneWidget,
      );
      expect(find.text('Criar usuário'), findsOneWidget);
    });
  });
}
