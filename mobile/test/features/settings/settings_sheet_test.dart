import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/theme_controller.dart';
import 'package:mobile/core/widgets/app_bottom_sheet.dart';
import 'package:mobile/features/settings/presentation/widgets/settings_sheet.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  late FakePreferencesStorage preferences;
  late ThemeController theme;
  var usersOpened = 0;
  var loggedOut = 0;

  setUp(() {
    preferences = FakePreferencesStorage();
    theme = ThemeController(preferences);
    usersOpened = 0;
    loggedOut = 0;
  });
  tearDown(() => theme.dispose());

  Future<void> openSheet(WidgetTester tester, {double height = 800}) async {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => SettingsSheet.show(
            context,
            themeController: theme,
            onOpenUsers: () => usersOpened++,
            onLogout: () => loggedOut++,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('SettingsSheet', () {
    testWidgets('shows_the_theme_options_the_users_entry_and_logout', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('Configurações'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);
      expect(find.text('Usuários'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
    });

    testWidgets('it_is_a_modal_sheet_of_at_most_80_percent_of_the_screen', (
      tester,
    ) async {
      await openSheet(tester, height: 400);

      final height = tester.getSize(find.byType(BottomSheet)).height;
      expect(height, lessThanOrEqualTo(400 * appSheetMaxHeightFraction));
    });

    testWidgets('logout_is_the_last_thing_in_the_sheet', (tester) async {
      await openSheet(tester);

      final usersBottom = tester.getBottomLeft(find.text('Usuários')).dy;
      final logoutTop = tester.getTopLeft(find.text('Sair')).dy;
      expect(logoutTop, greaterThan(usersBottom));
    });

    testWidgets('the_current_theme_is_the_one_selected', (tester) async {
      await tester.pumpWidget(const SizedBox());
      await theme.setMode(ThemeMode.dark);
      await openSheet(tester);

      final button = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(button.selected, {ThemeMode.dark});
    });

    testWidgets('choosing_a_theme_changes_it_and_saves_it', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Escuro'));
      await tester.pumpAndSettle();

      expect(theme.mode, ThemeMode.dark);
      expect(preferences.values[ThemeController.preferenceKey], 'dark');
      final button = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(button.selected, {ThemeMode.dark});
    });

    testWidgets('a_new_controller_starts_with_the_saved_theme', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();

      final reopened = ThemeController(preferences);

      expect(reopened.mode, ThemeMode.light);
      reopened.dispose();
    });

    testWidgets('choosing_the_device_theme_goes_back_to_system', (
      tester,
    ) async {
      await theme.setMode(ThemeMode.dark);
      await openSheet(tester);

      await tester.tap(find.text('Sistema'));
      await tester.pumpAndSettle();

      expect(theme.mode, ThemeMode.system);
      expect(preferences.values[ThemeController.preferenceKey], 'system');
    });

    testWidgets('the_users_entry_closes_the_sheet_and_opens_the_users', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.text('Usuários'));
      await tester.pumpAndSettle();

      expect(usersOpened, 1);
      expect(find.text('Configurações'), findsNothing);
    });

    testWidgets('logout_closes_the_sheet_and_ends_the_session', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(loggedOut, 1);
      expect(find.text('Configurações'), findsNothing);
    });
  });
}
