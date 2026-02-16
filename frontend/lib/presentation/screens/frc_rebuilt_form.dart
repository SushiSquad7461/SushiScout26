import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../core/validation/form_validators.dart';
import '../../data/models/match_report.dart';
import '../../data/repositories/hybrid_repository.dart';
import '../widgets/scouting_form_widget.dart';
import '../widgets/match_timer.dart';
import '../widgets/counter_card.dart';
import '../widgets/image_picker_widget.dart';
import '../../data/local/preferences.dart';
import '../theme/app_theme.dart';

/// FRC "Rebuilt" 2026 scouting form with Material 3 styling.
class FrcRebuiltForm extends ScoutingFormWidget {
  const FrcRebuiltForm({
    super.key,
    required super.eventId,
    required super.event,
  });

  @override
  ConsumerState<FrcRebuiltForm> createState() => _FrcRebuiltFormState();

  @override
  Map<String, dynamic> collectGameData() => {};
}

class _FrcRebuiltFormState extends ConsumerState<FrcRebuiltForm> {
  final PageController _pageController = PageController();
  final MatchTimerController _timerController = MatchTimerController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  int _currentPage = 0;

  // Form Data
  final _matchNumberCtrl = TextEditingController();
  final _teamNumberCtrl = TextEditingController();
  String _alliance = 'Red';
  final _scouterNameCtrl = TextEditingController();

  // Auto
  int _autoFuel = 0;
  bool _autoTowerL1 = false;

  // Teleop
  int _teleopFuel = 0;
  int _teleopTower = 0;

  // Qualitative
  int _defense = 0;
  int _skill = 0;
  bool _died = false;
  final _commentsCtrl = TextEditingController();
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _scouterNameCtrl.text = settings[PrefKeys.scouterName] ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _matchNumberCtrl.dispose();
    _teamNumberCtrl.dispose();
    _scouterNameCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      _timerController.start();
    }

    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.name),
        bottom: MatchTimer(controller: _timerController),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            children: [
              _buildPage("Setup", _buildSetup(context)),
              _buildPage("Autonomous", _buildAuto(context)),
              _buildPage("Teleop", _buildTeleop(context)),
              _buildPage("Endgame", _buildEndgame(context)),
              _buildPage("Review & Submit", _buildReview(context)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, colorScheme),
    );
  }

  Widget _buildBottomBar(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.spacingMd,
        right: AppTheme.spacingMd,
        top: AppTheme.spacingSm,
        bottom: MediaQuery.of(context).viewPadding.bottom + AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          // Back button
          if (_currentPage > 0)
            TextButton.icon(
              onPressed: _prevPage,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text("Back"),
            )
          else
            const SizedBox(width: 100),

          const Spacer(),

          // Page indicator
          _buildPageIndicator(colorScheme),

          const Spacer(),

          // Next/Submit button
          FilledButton.icon(
            onPressed: _nextPage,
            icon: Icon(
              _currentPage == 4
                  ? Icons.check_rounded
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(_currentPage == 4 ? "Submit" : "Next"),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final isActive = _currentPage == index;
        final isPast = index < _currentPage;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? colorScheme.primary
                : isPast
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerHighest,
          ),
        );
      }),
    );
  }

  Widget _buildPage(String title, Widget content) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppTheme.spacingSm),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spacingMd),
          Expanded(child: SingleChildScrollView(child: content)),
        ],
      ),
    );
  }

  Widget _buildSetup(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _scouterNameCtrl,
          decoration: const InputDecoration(
            labelText: "Scouter Name",
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          validator: (v) => FormValidators.required(v, "Scouter Name"),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: AppTheme.spacingMd),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _matchNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Match #",
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: FormValidators.matchNumber,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: TextFormField(
                controller: _teamNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Team #",
                  prefixIcon: Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: FormValidators.teamNumber,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spacingLg),

        Text(
          "Alliance",
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.spacingSm),

        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Red',
              label: Text('Red Alliance'),
              icon: Icon(Icons.shield, color: Colors.red),
            ),
            ButtonSegment(
              value: 'Blue',
              label: Text('Blue Alliance'),
              icon: Icon(Icons.shield, color: Colors.blue),
            ),
          ],
          selected: {_alliance},
          onSelectionChanged: (val) => setState(() => _alliance = val.first),
          showSelectedIcon: false,
        ),
      ],
    );
  }

  // ... (Auto, Teleop, Endgame, Review, Submit methods need update)
  // I will update the rest in the next block to ensure full file replacement or just critical parts.
  // Actually, I can replace the rest as well to update _submit.
  
  Widget _buildAuto(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final fuelIncrement = int.tryParse(settings[PrefKeys.fuelIncrement] ?? '1') ?? 1;

    return Column(
      children: [
        CounterCard(
          label: "Auto Fuel",
          helperText: "Pieces scored during autonomous",
          value: _autoFuel,
          onChanged: (v) => setState(() => _autoFuel = v),
          stepSize: fuelIncrement,
          showStepControl: true,
          onStepChanged: (step) => ref.read(settingsProvider.notifier).setFuelIncrement(step.toString()),
          accentColor: Theme.of(context).colorScheme.tertiary,
        ),
        const SizedBox(height: AppTheme.spacingMd),

        Card(
          child: SwitchListTile(
            title: const Text("L1 Hang"),
            subtitle: const Text("Robot achieved L1 hang"),
            value: _autoTowerL1,
            onChanged: (v) => setState(() => _autoTowerL1 = v),
          ),
        ),
      ],
    );
  }

  Widget _buildTeleop(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final fuelIncrement = int.tryParse(settings[PrefKeys.fuelIncrement] ?? '1') ?? 1;

    return Column(
      children: [
        CounterCard(
          label: "Teleop Fuel",
          helperText: "Pieces scored during teleop",
          value: _teleopFuel,
          onChanged: (v) => setState(() => _teleopFuel = v),
          stepSize: fuelIncrement,
          showStepControl: true,
          onStepChanged: (step) => ref.read(settingsProvider.notifier).setFuelIncrement(step.toString()),
        ),

        const SizedBox(height: AppTheme.spacingMd),

        Card(
          color: _died
              ? colorScheme.errorContainer.withValues(alpha: 0.5)
              : null,
          child: CheckboxListTile(
            title: Text(
              "Robot Died / Disabled",
              style: TextStyle(color: _died ? colorScheme.error : null),
            ),
            subtitle: const Text("Robot was inactive during match"),
            value: _died,
            onChanged: (v) => setState(() => _died = v!),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ],
    );
  }

  Widget _buildEndgame(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Climb dropdown
        DropdownButtonFormField<int>(
          value: _teleopTower,
          decoration: const InputDecoration(
            labelText: "Climb Result",
            prefixIcon: Icon(Icons.trending_up),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 0, child: Text("No Climb")),
            DropdownMenuItem(value: 1, child: Text("Level 1 Climb")),
            DropdownMenuItem(value: 2, child: Text("Level 2 Climb")),
            DropdownMenuItem(value: 3, child: Text("Level 3 Climb")),
          ],
          onChanged: (v) => setState(() => _teleopTower = v!),
        ),

        const SizedBox(height: AppTheme.spacingLg),

        Text("Qualitative Metrics", style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingMd),

        _buildSlider(
          context,
          label: "Defense Rating",
          value: _defense,
          onChanged: (v) => setState(() => _defense = v),
        ),

        _buildSlider(
          context,
          label: "Driver Skill",
          value: _skill,
          onChanged: (v) => setState(() => _skill = v),
        ),

        const SizedBox(height: AppTheme.spacingMd),

        TextFormField(
          controller: _commentsCtrl,
          decoration: const InputDecoration(
            labelText: "Comments",
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.comment_outlined),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        
        const SizedBox(height: AppTheme.spacingMd),
        
        ImagePickerWidget(
          initialImages: _images,
          onImagesChanged: (images) => _images = images,
        ),
      ],
    );
  }

  Widget _buildSlider(
    BuildContext context, {
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: AppTheme.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.spacingSm),
                  ),
                  child: Text(
                    "$value/5",
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: value.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              onChanged: (v) => onChanged(v.toInt()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allianceColor = _alliance == 'Red' ? Colors.red : Colors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header card
        Card(
          color: allianceColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              children: [
                Text(
                  "Team ${_teamNumberCtrl.text}",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: allianceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Match ${_matchNumberCtrl.text} • $_alliance Alliance",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppTheme.spacingMd),

        // Data summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              children: [
                _ReviewRow(label: "Auto Fuel", value: "$_autoFuel"),
                _ReviewRow(
                  label: "Left Line (L1)",
                  value: _autoTowerL1 ? "Yes" : "No",
                ),
                const Divider(height: AppTheme.spacingLg),
                _ReviewRow(label: "Teleop Fuel", value: "$_teleopFuel"),
                _ReviewRow(label: "Climb Level", value: "Level $_teleopTower"),
                const Divider(height: AppTheme.spacingLg),
                _ReviewRow(label: "Defense", value: "$_defense/5"),
                _ReviewRow(label: "Driver Skill", value: "$_skill/5"),
                if (_died) ...[
                  const SizedBox(height: AppTheme.spacingSm),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSm),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppTheme.spacingSm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning, color: colorScheme.error, size: 20),
                        const SizedBox(width: AppTheme.spacingSm),
                        Text(
                          "Robot Died",
                          style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final gameData = {
      'auto_fuel': _autoFuel,
      'auto_tower_l1': _autoTowerL1,
      'teleop_fuel': _teleopFuel,
      'teleop_tower_level': _teleopTower,
      'defense_rating': _defense,
      'driver_skill': _skill,
    };

    final report = MatchReport(
      id: "${widget.eventId}_qm${_matchNumberCtrl.text}_${_teamNumberCtrl.text}",
      matchId: "${widget.eventId}_qm${_matchNumberCtrl.text}",
      matchNumber: int.tryParse(_matchNumberCtrl.text) ?? 0,
      teamNumber: int.tryParse(_teamNumberCtrl.text) ?? 0,
      alliance: _alliance,
      scouterName: _scouterNameCtrl.text,
      gameData: gameData,
      robotDied: _died,
      comments: _commentsCtrl.text,
      images: _images,
      createdAt: DateTime.now(),
      isSynced: false,
    );

    try {
      await ref.read(hybridRepositoryProvider).createMatch(widget.eventId, report);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Match Saved!")));
        Navigator.pop(context);
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving: $e"), backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
