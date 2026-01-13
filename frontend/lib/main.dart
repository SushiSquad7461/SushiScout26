import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data/local/db.dart';
import 'presentation/screens/scouting_wizard.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'data/local/preferences.dart';
import 'presentation/screens/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: SushiScoutApp(db: db),
    ),
  );
}

class SushiScoutApp extends ConsumerWidget {
  final AppDatabase db;
  const SushiScoutApp({super.key, required this.db});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeModeStr = settings[PrefKeys.themeMode] ?? 'system';
    final colorSeedStr = settings[PrefKeys.colorSeed] ?? 'salmon';

    final ThemeMode mode = switch (themeModeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final Color seedColor = switch (colorSeedStr) {
      'blue' => Colors.blue,
      'green' => Colors.green,
      'purple' => Colors.purple,
      'orange' => Colors.orange,
      _ => const Color(0xFFFA8072), // Salmon
    };

    return MaterialApp(
      title: 'SushiScout 26',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: mode,
      home: DashboardScreen(db: db),
    );
  }
}
