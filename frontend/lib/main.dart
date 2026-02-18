import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'data/repositories/firestore_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/local/preferences.dart';
import 'data/local/sync/sync_manager.dart';
import 'presentation/screens/dashboard.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence for 100% offline-first reliability
  // Critical for poor connections or Firebase outages
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final prefs = await SharedPreferences.getInstance();
  
  // Create container to initialize services
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      firestoreRepositoryProvider.overrideWithValue(
        FirestoreRepository(FirebaseFirestore.instance),
      ),
    ],
  );

  // Initialize SyncManager
  container.read(syncManagerProvider).initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SushiScoutApp(),
    ),
  );
}

class SushiScoutApp extends ConsumerWidget {
  const SushiScoutApp({super.key});

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
      home: const DashboardScreen(),
    );
  }
}
