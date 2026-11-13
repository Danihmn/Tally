import 'package:shared_preferences/shared_preferences.dart';

/// Storage for non-sensitive settings: theme mode, selected scope, flags.
///
/// Never put tokens or financial data here (it is plain text on disk).
abstract interface class PreferencesStorage {
  String? getString(String key);

  Future<void> setString(String key, String value);

  bool? getBool(String key);

  Future<void> setBool(String key, {required bool value});

  Future<void> remove(String key);
}

/// [PreferencesStorage] backed by `shared_preferences`.
class SharedPreferencesStorage implements PreferencesStorage {
  SharedPreferencesStorage(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
