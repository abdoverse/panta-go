import 'package:shared_preferences/shared_preferences.dart';
import 'session_vault.dart';

SessionVault getDefaultSessionVault() => SharedPreferencesSessionVault();

/// Non-web / VM implementation of [SessionVault] backed by [SharedPreferences].
///
/// On mobile platforms (Android / iOS) where app instances are natively isolated
/// per device install, [SharedPreferences] maintains persistent login across app restarts.
class SharedPreferencesSessionVault implements SessionVault {
  @override
  Future<void> setItem(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<String?> getItem(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> removeItem(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('panta_custom_jwt');
    await prefs.remove('panta_custom_display_names');
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }
}
