import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data/local/db.dart';
import 'presentation/screens/scouting_wizard.dart';

void main() {
  final db = AppDatabase();
  runApp(ProviderScope(child: SushiScoutApp(db: db)));
}

class SushiScoutApp extends StatelessWidget {
  final AppDatabase db;
  const SushiScoutApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SushiScout 26',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA8072), // Salmon/Sushi Color
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA8072),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: ThemeMode.system,
      home: HomeScreen(db: db),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final AppDatabase db;
  const HomeScreen({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SushiScout 26")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ramen_dining, size: 64, color: Color(0xFFFA8072)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ScoutingWizard(db: db),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text("Scout Match"),
            ),
          ],
        ),
      ),
    );
  }
}
