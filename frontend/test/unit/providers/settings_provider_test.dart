import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Settings Provider', () {
    late ProviderContainer container;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should have default values', () {
      final settings = container.read(settingsProvider);

      expect(settings[PrefKeys.scouterName], '');
      expect(settings[PrefKeys.eventCode], '');
      expect(settings[PrefKeys.themeMode], 'system');
      expect(settings[PrefKeys.colorSeed], 'salmon');
    });

    test('should update scouter name', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setScouterName('Test Scouter');

      final settings = container.read(settingsProvider);
      expect(settings[PrefKeys.scouterName], 'Test Scouter');
    });

    test('should update event code', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setEventCode('2026casj');

      final settings = container.read(settingsProvider);
      expect(settings[PrefKeys.eventCode], '2026casj');
    });

    test('should update theme mode', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setThemeMode('dark');

      final settings = container.read(settingsProvider);
      expect(settings[PrefKeys.themeMode], 'dark');
    });

    test('should update color seed', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setColorSeed('blue');

      final settings = container.read(settingsProvider);
      expect(settings[PrefKeys.colorSeed], 'blue');
    });

    test('should persist settings across reads', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setScouterName('Persistent Scouter');
      await notifier.setEventCode('2026test');

      // Create a new container to simulate app restart
      final newContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final settings = newContainer.read(settingsProvider);
      expect(settings[PrefKeys.scouterName], 'Persistent Scouter');
      expect(settings[PrefKeys.eventCode], '2026test');

      newContainer.dispose();
    });

    test('should handle empty strings', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setScouterName('');
      await notifier.setEventCode('');

      final settings = container.read(settingsProvider);
      expect(settings[PrefKeys.scouterName], '');
      expect(settings[PrefKeys.eventCode], '');
    });

    test('should handle special characters', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setScouterName('Scouter @ Event #1');

      final settings = container.read(settingsProvider);
      expect(settings[PrefKeys.scouterName], 'Scouter @ Event #1');
    });

    group('theme modes', () {
      test('should support light theme', () async {
        final notifier = container.read(settingsProvider.notifier);
        await notifier.setThemeMode('light');

        final settings = container.read(settingsProvider);
        expect(settings[PrefKeys.themeMode], 'light');
      });

      test('should support dark theme', () async {
        final notifier = container.read(settingsProvider.notifier);
        await notifier.setThemeMode('dark');

        final settings = container.read(settingsProvider);
        expect(settings[PrefKeys.themeMode], 'dark');
      });

      test('should support system theme', () async {
        final notifier = container.read(settingsProvider.notifier);
        await notifier.setThemeMode('system');

        final settings = container.read(settingsProvider);
        expect(settings[PrefKeys.themeMode], 'system');
      });
    });

    group('color seeds', () {
      test('should support all color seeds', () async {
        final notifier = container.read(settingsProvider.notifier);
        final colors = ['salmon', 'blue', 'green', 'purple', 'orange'];

        for (final color in colors) {
          await notifier.setColorSeed(color);
          final settings = container.read(settingsProvider);
          expect(settings[PrefKeys.colorSeed], color);
        }
      });
    });
  });
}
