import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../data/local/db.dart';
import '../../data/local/preferences.dart';
import 'scouting_wizard.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final AppDatabase db;
  const DashboardScreen({super.key, required this.db});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Stream<List<MatchEntry>> _matchesStream;

  @override
  void initState() {
    super.initState();
    _matchesStream = widget.db.select(widget.db.matchEntries).watch();
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SettingsSheet(),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final matches = await widget.db.select(widget.db.matchEntries).get();
    if (matches.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No matches to export.")));
      return;
    }

    // Generate CSV String
    final header =
        "Match,Team,Alliance,Auto Fuel,Auto Tower L1,Teleop Fuel,Teleop Tower Level,Defense,Driver Skill,Comments,Synced\n";
    final rows = matches
        .map((m) {
          return "${m.matchNumber},${m.teamNumber},${m.alliance},${m.autoFuel},${m.autoTowerL1},${m.teleopFuel},${m.teleopTowerLevel},${m.defenseRating},${m.driverSkill},\"${m.comments.replaceAll('\n', ' ')}\",${m.isSynced}";
        })
        .join("\n");

    final csvContent = header + rows;

    // Save & Share using platform channels (requires services, imported below)
    try {
      // We need to implement this via a service or inline.
      // For cleanliness, I'll assume we import specific packages or just do it here if simple.
      // Since I have share_plus and path_provider, I need to look up how to use them.
      // But I need the imports first.

      await _shareFile(csvContent);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Export failed: $e")));
    }
  }

  Future<void> _shareFile(String content) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/sushiscout26_export.csv');
      await file.writeAsString(content);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'SushiScout 26 Match Data');
    } catch (e) {
      debugPrint("Sharing failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error sharing file: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final eventCode = settings[PrefKeys.eventCode] ?? "Unknown Event";

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SushiScout 26"),
            Text(eventCode, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Export CSV",
            onPressed: () => _exportCsv(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ScoutingWizard(db: widget.db),
            ),
          );
        },
        label: const Text("Scout Match"),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<MatchEntry>>(
        stream: _matchesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.ramen_dining,
                    size: 64,
                    color: Color(0xFFFA8072),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No matches scouted yet.",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Desktop/Tablet Grid
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 3 / 1, // Wide cards
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: matches.length,
                  itemBuilder: (context, index) =>
                      _MatchCard(match: matches[index]),
                );
              } else {
                // Mobile List
                return ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) =>
                      _MatchCard(match: matches[index]),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchEntry match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: match.alliance == 'Red'
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.blue.withValues(alpha: 0.2),
          child: Text(
            "${match.matchNumber}",
            style: TextStyle(
              color: match.alliance == 'Red' ? Colors.red : Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text("Team ${match.teamNumber}"),
        subtitle: Text("Auto: ${match.autoFuel} | Tele: ${match.teleopFuel}"),
        trailing: match.isSynced
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
      ),
    );
  }
}

class _SettingsSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  final _serverIpCtrl = TextEditingController();
  final _scouterNameCtrl = TextEditingController();
  final _eventCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _serverIpCtrl.text = settings[PrefKeys.serverIp] ?? '';
    _scouterNameCtrl.text = settings[PrefKeys.scouterName] ?? '';
    _eventCodeCtrl.text = settings[PrefKeys.eventCode] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Settings", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          TextField(
            controller: _scouterNameCtrl,
            decoration: const InputDecoration(
              labelText: "Your Name",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            onChanged: (val) =>
                ref.read(settingsProvider.notifier).setScouterName(val),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _eventCodeCtrl,
            decoration: const InputDecoration(
              labelText: "Event Code",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event),
            ),
            onChanged: (val) =>
                ref.read(settingsProvider.notifier).setEventCode(val),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          // Theme Mode Selector
          DropdownButtonFormField<String>(
            value: ref.watch(settingsProvider)[PrefKeys.themeMode] ?? 'system',
            decoration: const InputDecoration(
              labelText: "Theme Mode",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.brightness_6),
            ),
            items: const [
              DropdownMenuItem(value: 'system', child: Text("System")),
              DropdownMenuItem(value: 'light', child: Text("Light")),
              DropdownMenuItem(value: 'dark', child: Text("Dark")),
            ],
            onChanged: (val) {
              if (val != null) {
                ref.read(settingsProvider.notifier).setThemeMode(val);
              }
            },
          ),
          const SizedBox(height: 16),
          // Color Seed Selector
          const Text(
            "App Color Theme",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ColorSeedChip(
                  label: 'Salmon',
                  value: 'salmon',
                  color: const Color(0xFFFA8072),
                ),
                _ColorSeedChip(
                  label: 'Blue',
                  value: 'blue',
                  color: Colors.blue,
                ),
                _ColorSeedChip(
                  label: 'Green',
                  value: 'green',
                  color: Colors.green,
                ),
                _ColorSeedChip(
                  label: 'Purple',
                  value: 'purple',
                  color: Colors.purple,
                ),
                _ColorSeedChip(
                  label: 'Orange',
                  value: 'orange',
                  color: Colors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _serverIpCtrl,
            decoration: const InputDecoration(
              labelText: "Server URL",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cloud),
              hintText: "http://10.0.0.X:8000",
            ),
            onChanged: (val) =>
                ref.read(settingsProvider.notifier).setServerIp(val),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Done"),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
