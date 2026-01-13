import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys
class PrefKeys {
  static const String serverIp = 'server_ip';
  static const String scouterName = 'scouter_name';
  static const String eventCode = 'event_code';
  static const String themeMode = 'theme_mode'; // 'system', 'light', 'dark'
}

// Provider for SharedPreferences instance (overridden in main)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

// Settings Notifier
class SettingsNotifier extends StateNotifier<Map<String, String>> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
    : super({
        PrefKeys.serverIp:
            _prefs.getString(PrefKeys.serverIp) ?? 'http://10.0.0.5:8000',
        PrefKeys.scouterName: _prefs.getString(PrefKeys.scouterName) ?? '',
        PrefKeys.eventCode: _prefs.getString(PrefKeys.eventCode) ?? '2026TEST',
        PrefKeys.themeMode: _prefs.getString(PrefKeys.themeMode) ?? 'system',
      });

  Future<void> setServerIp(String value) async {
    await _prefs.setString(PrefKeys.serverIp, value);
    state = {...state, PrefKeys.serverIp: value};
  }

  Future<void> setScouterName(String value) async {
    await _prefs.setString(PrefKeys.scouterName, value);
    state = {...state, PrefKeys.scouterName: value};
  }

  Future<void> setEventCode(String value) async {
    await _prefs.setString(PrefKeys.eventCode, value);
    state = {...state, PrefKeys.eventCode: value};
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Map<String, String>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return SettingsNotifier(prefs);
    });
