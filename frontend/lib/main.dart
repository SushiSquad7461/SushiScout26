import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'data/repositories/scouting_repository.dart';
import 'data/repositories/firestore_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/local/preferences.dart';
import 'presentation/screens/dashboard.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline persistence is enabled by default in recent SDKs, but ensuring settings:
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final prefs = await SharedPreferences.getInstance();
  final repository = FirestoreRepository(FirebaseFirestore.instance);

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: SushiScoutApp(repository: repository),
    ),
  );
}

class SushiScoutApp extends ConsumerWidget {
  final ScoutingRepository repository;
  const SushiScoutApp({super.key, required this.repository});

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

    final Color seedColor = AppTheme.getSeedColor(colorSeedStr);

    return MaterialApp(
      title: 'SushiScout 26',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(seedColor),
      darkTheme: AppTheme.darkTheme(seedColor),
      themeMode: mode,
      home: DashboardScreen(repository: repository),
    );
  }
}
