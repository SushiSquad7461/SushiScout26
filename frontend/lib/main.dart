import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'data/repositories/firestore_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/local/preferences.dart';
import 'data/repositories/providers.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/widgets/auth_wrapper.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final prefs = await SharedPreferences.getInstance();
  
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      activeTeamIdProvider.overrideWith((ref) => ref.watch(currentTeamIdProvider)),
      firestoreRepositoryProvider.overrideWith((ref) {
        final teamId = ref.watch(activeTeamIdProvider);
        return FirestoreRepository(FirebaseFirestore.instance, teamId: teamId);
      }),
    ],
  );

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
      home: const AuthWrapper(),
    );
  }
}
