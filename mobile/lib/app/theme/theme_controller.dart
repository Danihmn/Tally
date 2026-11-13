import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/storage/preferences_storage.dart';

/// Holds the theme mode and saves it in preferences. App-wide, so it lives in
/// `app/` and not in a feature. The settings screen (phase 2) changes it.
class ThemeController extends ChangeNotifier {
  ThemeController(this._preferences) : _mode = _read(_preferences);

  static const preferenceKey = 'theme_mode';

  final PreferencesStorage _preferences;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _preferences.setString(preferenceKey, mode.name);
  }

  static ThemeMode _read(PreferencesStorage preferences) {
    final saved = preferences.getString(preferenceKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }
}
