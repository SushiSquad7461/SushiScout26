import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys
class PrefKeys {
  static const String scouterName = 'scouter_name';
  static const String eventCode = 'event_code';
  static const String themeMode = 'theme_mode'; // 'system', 'light', 'dark'
  static const String colorSeed =
      'color_seed'; // 'salmon', 'blue', 'green', 'purple'
  static const String fuelIncrement = 'fuel_increment';
  static const String programType = 'program_type';
}

// Provider for SharedPreferences instance (overridden in main)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

// Settings Notifier
class SettingsNotifier extends Notifier<Map<String, String>> {
  late SharedPreferences _prefs;

  @override
  Map<String, String> build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return {
      PrefKeys.scouterName: _prefs.getString(PrefKeys.scouterName) ?? '',
      PrefKeys.eventCode: _prefs.getString(PrefKeys.eventCode) ?? '2026TEST',
      PrefKeys.themeMode: _prefs.getString(PrefKeys.themeMode) ?? 'system',
      PrefKeys.colorSeed: _prefs.getString(PrefKeys.colorSeed) ?? 'salmon',
      PrefKeys.fuelIncrement: _prefs.getString(PrefKeys.fuelIncrement) ?? '1',
      PrefKeys.programType: _prefs.getString(PrefKeys.programType) ?? 'FRC',
    };
  }

  Future<void> setScouterName(String value) async {
    await _prefs.setString(PrefKeys.scouterName, value);
    state = {...state, PrefKeys.scouterName: value};
  }

  Future<void> setEventCode(String value) async {
    await _prefs.setString(PrefKeys.eventCode, value);
    state = {...state, PrefKeys.eventCode: value};
  }

  Future<void> setThemeMode(String value) async {
    await _prefs.setString(PrefKeys.themeMode, value);
    state = {...state, PrefKeys.themeMode: value};
  }

  Future<void> setColorSeed(String value) async {
    await _prefs.setString(PrefKeys.colorSeed, value);
    state = {...state, PrefKeys.colorSeed: value};
  }

  Future<void> setFuelIncrement(String value) async {
    await _prefs.setString(PrefKeys.fuelIncrement, value);
    state = {...state, PrefKeys.fuelIncrement: value};
  }

  Future<void> setProgramType(String value) async {
    await _prefs.setString(PrefKeys.programType, value);
    state = {...state, PrefKeys.programType: value};
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Map<String, String>>(
      SettingsNotifier.new,
    );
