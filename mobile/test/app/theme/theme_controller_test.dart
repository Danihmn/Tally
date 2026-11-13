import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/theme_controller.dart';

import '../../support/fakes.dart';

void main() {
  group('ThemeController', () {
    test('starts_with_system_mode_when_nothing_was_saved', () {
      expect(ThemeController(FakePreferencesStorage()).mode, ThemeMode.system);
    });

    test('saves_the_mode_and_restores_it_on_start', () async {
      final prefs = FakePreferencesStorage();
      final controller = ThemeController(prefs);
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setMode(ThemeMode.dark);

      expect(notified, 1);
      expect(prefs.getString(ThemeController.preferenceKey), 'dark');
      expect(ThemeController(prefs).mode, ThemeMode.dark);
    });

    test('ignores_an_unknown_saved_value', () {
      final prefs = FakePreferencesStorage()
        ..values[ThemeController.preferenceKey] = 'neon';
      expect(ThemeController(prefs).mode, ThemeMode.system);
    });

    test('does_not_notify_when_the_mode_does_not_change', () async {
      final controller = ThemeController(FakePreferencesStorage());
      var notified = 0;
      controller.addListener(() => notified++);
      await controller.setMode(ThemeMode.system);
      expect(notified, 0);
    });
  });
}
