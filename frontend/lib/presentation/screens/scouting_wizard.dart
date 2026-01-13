import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/db.dart';
import '../widgets/counter_card.dart';

class ScoutingWizard extends StatefulWidget {
  final AppDatabase db;
  const ScoutingWizard({super.key, required this.db});

  @override
  State<ScoutingWizard> createState() => _ScoutingWizardState();
}

class _ScoutingWizardState extends State<ScoutingWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Data State
  final _scouterNameCtrl = TextEditingController();
  final _matchNumberCtrl = TextEditingController();
  final _teamNumberCtrl =
      TextEditingController(); // TODO: Add filtering/validation
  String _alliance = 'Red';

  // Auto
  int _autoFuel = 0;
  bool _autoTowerL1 = false;

  // Teleop
  int _teleopFuel = 0;
  int _teleopTower = 0; // 0=None

  // Endgame/Qual
  int _defense = 0;
  int _skill = 0;
  bool _died = false;
  final _commentsCtrl = TextEditingController();

  void _nextPage() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Match ${_matchNumberCtrl.text.isEmpty ? 'Setup' : _matchNumberCtrl.text}",
        ),
        backgroundColor: colorScheme.surfaceContainer,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 4,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildSetupStep(colorScheme),
          _buildAutoStep(colorScheme),
          _buildTeleopStep(colorScheme),
          _buildEndgameStep(colorScheme),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep > 0)
              TextButton.icon(
                onPressed: _prevPage,
                icon: const Icon(Icons.arrow_back),
                label: const Text("Back"),
              )
            else
              const SizedBox.shrink(),
            FilledButton.icon(
              onPressed: _nextPage,
              label: Text(_currentStep == 3 ? "Submit" : "Next"),
              icon: Icon(_currentStep == 3 ? Icons.check : Icons.arrow_forward),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupStep(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          "Pre-Match Setup",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _scouterNameCtrl,
          decoration: const InputDecoration(
            labelText: "Scouter Name",
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _matchNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Match #",
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _teamNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Team #",
                  prefixIcon: Icon(Icons.group),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text("Alliance", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Red',
              label: Text("Red"),
              icon: Icon(Icons.shield, color: Colors.red),
            ),
            ButtonSegment(
              value: 'Blue',
              label: Text("Blue"),
              icon: Icon(Icons.shield, color: Colors.blue),
            ),
          ],
          selected: {_alliance},
          onSelectionChanged: (Set<String> val) =>
              setState(() => _alliance = val.first),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return _alliance == 'Red'
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.blue.withValues(alpha: 0.2);
              }
              return Colors.transparent;
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoStep(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text("Autonomous", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        CounterCard(
          label: "Auto Fuel",
          value: _autoFuel,
          onChanged: (v) => setState(() => _autoFuel = v),
          color: colors.primaryContainer,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text("Tower L1 Climb"),
          subtitle: const Text("15 Points"),
          value: _autoTowerL1,
          onChanged: (v) => setState(() => _autoTowerL1 = v),
          tileColor: colors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  Widget _buildTeleopStep(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text("Teleop", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        CounterCard(
          label: "Teleop Fuel",
          value: _teleopFuel,
          onChanged: (v) => setState(() => _teleopFuel = v),
          color: colors.secondaryContainer,
          helperText: "Only count when Hub is ACTIVE",
        ),
        const SizedBox(height: 24),
        CheckboxListTile(
          title: const Text("Robot Died / Disabled"),
          value: _died,
          onChanged: (v) => setState(() => _died = v!),
          tileColor: colors.errorContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  Widget _buildEndgameStep(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text("Endgame", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Climb Level",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _teleopTower,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text("None (0 pts)")),
                    DropdownMenuItem(value: 1, child: Text("Level 1 (10 pts)")),
                    DropdownMenuItem(value: 2, child: Text("Level 2 (20 pts)")),
                    DropdownMenuItem(value: 3, child: Text("Level 3 (30 pts)")),
                  ],
                  onChanged: (v) => setState(() => _teleopTower = v!),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text("Qualitative", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _buildRatingSlider(
          "Defense",
          _defense,
          (v) => setState(() => _defense = v),
        ),
        _buildRatingSlider(
          "Driver Skill",
          _skill,
          (v) => setState(() => _skill = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commentsCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: "Comments",
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSlider(String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label: $value/5"),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 5,
          divisions: 5,
          onChanged: (v) => onChanged(v.toInt()),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final entry = MatchEntriesCompanion.insert(
      id: DateTime.now().toIso8601String(), // Ideally use UUID
      scouterName: _scouterNameCtrl.text,
      eventCode: "2026TEST", // TODO: Settings
      matchNumber: int.tryParse(_matchNumberCtrl.text) ?? 0,
      teamNumber: int.tryParse(_teamNumberCtrl.text) ?? 0,
      alliance: _alliance,

      autoFuel: Value(_autoFuel),
      autoTowerL1: Value(_autoTowerL1),

      teleopFuel: Value(_teleopFuel),
      teleopTowerLevel: Value(_teleopTower),

      defenseRating: Value(_defense),
      driverSkill: Value(_skill),
      robotDied: Value(_died),
      comments: Value(_commentsCtrl.text),
    );

    await widget.db.into(widget.db.matchEntries).insert(entry);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Match Saved!")));
      // Navigate back...
      // Navigator.of(context).pop();
    }
  }
}
