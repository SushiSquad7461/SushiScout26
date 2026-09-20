import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/validation/form_validators.dart';
import '../../data/models/match_report.dart';
import '../../data/repositories/providers.dart';
import '../widgets/scouting_form_widget.dart';
import '../widgets/match_timer.dart';
import '../widgets/counter_card.dart';
import '../../data/local/preferences.dart';
import '../theme/app_theme.dart';
import '../../core/animations.dart';
import '../../data/services/schedule_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;

/// FRC "Rebuilt" 2026 scouting form with Material 3 styling.
class FrcRebuiltForm extends ScoutingFormWidget {
  const FrcRebuiltForm({
    super.key,
    required super.eventId,
    required super.event,
    super.existingMatch,
  });

  @override
  ConsumerState<FrcRebuiltForm> createState() => _FrcRebuiltFormState();

  @override
  Map<String, dynamic> collectGameData() => {};
}

class _FrcRebuiltFormState extends ConsumerState<FrcRebuiltForm>
    with KeyboardDismissMixin {
  final PageController _pageController = PageController();
  final MatchTimerController _timerController = MatchTimerController();
  final PhaseFlashController _phaseFlashController = PhaseFlashController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int _currentPage = 0;
  bool _submitting = false;

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
  bool _trenchTraverse = false;
  bool _bumpTraverse = false;
  bool _shootingRangeClose = false;
  bool _shootingRangeMid = false;
  bool _shootingRangeFar = false;

  // Qualitative
  int _defense = 0;
  int _skill = 0;
  String? _defenseCause;
  int _drivetrainSpeed = 0;
  int _intakeSpeed = 0;
  int _shooterSpeed = 0;
  bool _died = false;
  int? _diedAtSeconds;
  final _diedReasonCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();

  bool get _isEditing => widget.existingMatch != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMatch;
    if (existing != null) {
      _scouterNameCtrl.text = existing.scouterName;
      _matchNumberCtrl.text = '${existing.matchNumber}';
      _teamNumberCtrl.text = '${existing.teamNumber}';
      _alliance = existing.alliance;
      _autoFuel = existing.autoFuel;
      _autoTowerL1 = existing.autoTowerL1;
      _teleopFuel = existing.teleopFuel;
      _teleopTower = existing.teleopTowerLevel;
      _trenchTraverse = existing.trenchTraverse;
      _bumpTraverse = existing.bumpTraverse;
      _shootingRangeClose = existing.shootingRangeClose;
      _shootingRangeMid = existing.shootingRangeMid;
      _shootingRangeFar = existing.shootingRangeFar;
      _defense = existing.defenseRating;
      _skill = existing.driverSkill;
      _defenseCause = existing.defenseCause;
      _drivetrainSpeed = existing.drivetrainSpeed;
      _intakeSpeed = existing.intakeSpeed;
      _shooterSpeed = existing.shooterSpeed;
      _died = existing.robotDied;
      _diedAtSeconds = existing.diedAtSeconds;
      _diedReasonCtrl.text = existing.diedReason;
      _commentsCtrl.text = existing.comments;
    } else {
      final settings = ref.read(settingsProvider);
      _scouterNameCtrl.text = settings[PrefKeys.scouterName] ?? '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timerController.dispose();
    _phaseFlashController.dispose();
    _matchNumberCtrl.dispose();
    _teamNumberCtrl.dispose();
    _scouterNameCtrl.dispose();
    _diedReasonCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    final eventCode = widget.event.tbaKey;
    final programType = widget.event.programType;
    if (eventCode.isEmpty) return;

    try {
      await ref
          .read(scheduleServiceProvider)
          .fetchSchedule(eventCode: eventCode, programType: programType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not fetch schedule. Enter match details manually.',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    List<Map<String, dynamic>> scheduleMatches;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where('eventId', isEqualTo: eventCode)
          .where('programType', isEqualTo: programType)
          .orderBy('matchNumber')
          .get();

      scheduleMatches = snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not load schedule. Enter match details manually.',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    if (scheduleMatches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No schedule found. Enter match details manually.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: scheduleMatches.length,
        itemBuilder: (ctx, i) {
          final m = scheduleMatches[i];
          final matchNum = m['matchNumber'] ?? 0;
          final alliances = m['alliances'] as Map<String, dynamic>?;
          final teams = m['teams'] as List<dynamic>?;
          String subtitle = '';
          if (alliances != null) {
            final red =
                (alliances['red']?['team_keys'] as List?)?.join(', ') ?? '';
            final blue =
                (alliances['blue']?['team_keys'] as List?)?.join(', ') ?? '';
            subtitle = 'Red: $red | Blue: $blue';
          } else if (teams != null) {
            subtitle = teams.map((t) => '${t['teamNumber']}').join(', ');
          }
          return ListTile(
            title: Text('Match $matchNum'),
            subtitle: subtitle.isNotEmpty
                ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis)
                : null,
            onTap: () {
              _matchNumberCtrl.text = '$matchNum';
              Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }

  int get _pageCount => _isEditing ? 4 : 5;

  void _nextPage() {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_currentPage == 0 && !_isEditing) {
      _timerController.start();
    }

    if (_currentPage < _pageCount - 1) {
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

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _prevPage();
      },
      child: dismissKeyboardOnTap(
        child: PhaseFlashOverlay(
          controller: _phaseFlashController,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                _isEditing ? "edit • ${widget.event.name}" : widget.event.name,
              ),
              // Brand band sits between the app bar and the timer, as in the
              // design — the scout screen was the one screen missing it.
              bottom: ScoutingFormBrandBand(
                timerController: _timerController,
                onPhaseChanged: _phaseFlashController.flash,
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  if (_isEditing)
                    ScoutingLockedMatchBanner(
                      teamNumber: _teamNumberCtrl.text,
                      matchNumber: _matchNumberCtrl.text,
                      alliance: _alliance,
                    ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (idx) =>
                            setState(() => _currentPage = idx),
                        children: [
                          if (!_isEditing)
                            _buildPage("setup", _buildSetup(context)),
                          _buildPage("autonomous", _buildAuto(context)),
                          _buildPage("teleop", _buildTeleop(context)),
                          _buildPage("endgame", _buildEndgame(context)),
                          _buildPage("review & submit", _buildReview(context)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomBar(context, colorScheme),
          ),
        ),
      ),
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
          ScoutingWizardBottomSlot(
            child: _currentPage > 0
                ? TextButton.icon(
                    onPressed: _prevPage,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text("back"),
                  )
                : const SizedBox.shrink(),
          ),

          const Spacer(),

          // Page indicator
          _buildPageIndicator(colorScheme),

          const Spacer(),

          ScoutingWizardBottomSlot(
            child: ScoutingWizardNextButton(
              isLastPage: _currentPage == _pageCount - 1,
              submitting: _submitting,
              onPressed: _nextPage,
              finishLabel: _isEditing ? "save" : "submit",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(ColorScheme colorScheme) {
    return ScoutingWizardPageIndicator(
      colorScheme: colorScheme,
      currentPage: _currentPage,
      pageCount: _pageCount,
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
            labelText: "scouter name",
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          validator: (v) => FormValidators.required(v, "Scouter Name"),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: AppTheme.spacingMd),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('load schedule'),
          onPressed: _loadSchedule,
        ),
        const SizedBox(height: AppTheme.spacingMd),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _matchNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "match #",
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
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
                  labelText: "team #",
                  prefixIcon: Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                validator: FormValidators.teamNumber,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spacingLg),

        Text(
          "alliance",
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.spacingSm),

        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Red',
              label: Text('red alliance'),
              icon: Icon(Icons.shield, color: AppTheme.allianceRed),
            ),
            ButtonSegment(
              value: 'Blue',
              label: Text('blue alliance'),
              icon: Icon(Icons.shield, color: AppTheme.allianceBlue),
            ),
          ],
          selected: {_alliance},
          onSelectionChanged: (val) {
            AppHaptics.selection();
            setState(() => _alliance = val.first);
          },
          showSelectedIcon: false,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                final color = _alliance == 'Red'
                    ? AppTheme.allianceRed
                    : AppTheme.allianceBlue;
                return color.withValues(alpha: 0.2);
              }
              return null;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _alliance == 'Red'
                    ? AppTheme.allianceRed
                    : AppTheme.allianceBlue;
              }
              return null;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                final color = _alliance == 'Red'
                    ? AppTheme.allianceRed
                    : AppTheme.allianceBlue;
                return BorderSide(color: color, width: 2);
              }
              return null;
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildAuto(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final fuelIncrement =
        int.tryParse(settings[PrefKeys.fuelIncrement] ?? '1') ?? 1;

    return Column(
      children: [
        CounterCard(
          label: "Auto Fuel",
          helperText: "Pieces scored during autonomous",
          value: _autoFuel,
          onChanged: (v) => setState(() => _autoFuel = v),
          stepSize: fuelIncrement,
          showStepControl: true,
          onStepChanged: (step) => ref
              .read(settingsProvider.notifier)
              .setFuelIncrement(step.toString()),
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
    final fuelIncrement =
        int.tryParse(settings[PrefKeys.fuelIncrement] ?? '1') ?? 1;

    return Column(
      children: [
        CounterCard(
          label: "Teleop Fuel",
          helperText: "Pieces scored during teleop",
          value: _teleopFuel,
          onChanged: (v) => setState(() => _teleopFuel = v),
          stepSize: fuelIncrement,
          showStepControl: true,
          onStepChanged: (step) => ref
              .read(settingsProvider.notifier)
              .setFuelIncrement(step.toString()),
        ),

        const SizedBox(height: AppTheme.spacingMd),

        Card(
          color: _died
              ? colorScheme.errorContainer.withValues(alpha: 0.5)
              : null,
          child: Column(
            children: [
              CheckboxListTile(
                title: Text(
                  "Robot Died / Disabled",
                  style: TextStyle(color: _died ? colorScheme.error : null),
                ),
                subtitle: const Text("Robot was inactive during match"),
                value: _died,
                onChanged: (v) => setState(() {
                  _died = v!;
                  if (!_died) {
                    _diedAtSeconds = null;
                    _diedReasonCtrl.clear();
                  }
                }),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_died)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    0,
                    AppTheme.spacingMd,
                    AppTheme.spacingMd,
                  ),
                  child: RobotDiedTimeAndReason(
                    diedAtSeconds: _diedAtSeconds,
                    liveSecondsRemaining: _timerController.secondsRemaining,
                    onDiedAtSecondsChanged: (s) =>
                        setState(() => _diedAtSeconds = s),
                    reasonController: _diedReasonCtrl,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingMd),

        Text("Mobility", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingSm),

        Card(
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text("Trench Traverse"),
                subtitle: const Text("Robot can traverse the trench"),
                value: _trenchTraverse,
                onChanged: (v) => setState(() => _trenchTraverse = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                title: const Text("Bump Traverse"),
                subtitle: const Text("Robot can traverse the bump"),
                value: _bumpTraverse,
                onChanged: (v) => setState(() => _bumpTraverse = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingMd),

        Text("Shooting Range", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingSm),

        Card(
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text("Close Range"),
                value: _shootingRangeClose,
                onChanged: (v) => setState(() => _shootingRangeClose = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                title: const Text("Mid Range"),
                value: _shootingRangeMid,
                onChanged: (v) => setState(() => _shootingRangeMid = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                title: const Text("Far Range"),
                value: _shootingRangeFar,
                onChanged: (v) => setState(() => _shootingRangeFar = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
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
          initialValue: _teleopTower,
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
          onChanged: (v) => setState(() {
            _defense = v;
            if (v == 0) _defenseCause = null;
          }),
        ),

        if (_defense > 0)
          DefenseCauseSelector(
            cause: _defenseCause,
            onChanged: (v) => setState(() => _defenseCause = v),
          ),

        _buildSlider(
          context,
          label: "Driver Skill",
          value: _skill,
          onChanged: (v) => setState(() => _skill = v),
        ),

        _buildSlider(
          context,
          label: "Drivetrain Speed",
          value: _drivetrainSpeed,
          onChanged: (v) => setState(() => _drivetrainSpeed = v),
        ),

        _buildSlider(
          context,
          label: "Intake Speed",
          value: _intakeSpeed,
          onChanged: (v) => setState(() => _intakeSpeed = v),
        ),

        _buildSlider(
          context,
          label: "Shooter Speed",
          value: _shooterSpeed,
          onChanged: (v) => setState(() => _shooterSpeed = v),
        ),

        const SizedBox(height: AppTheme.spacingMd),

        TextFormField(
          controller: _commentsCtrl,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: "Comments",
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.comment_outlined),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
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
    final allianceColor = AppTheme.allianceColor(_alliance);

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
                  label: "Climb (L1)",
                  value: _autoTowerL1 ? "Yes" : "No",
                ),
                const Divider(height: AppTheme.spacingLg),
                _ReviewRow(label: "Teleop Fuel", value: "$_teleopFuel"),
                _ReviewRow(label: "Climb Level", value: "Level $_teleopTower"),
                const Divider(height: AppTheme.spacingLg),
                _ReviewRow(label: "Defense", value: "$_defense/5"),
                if (_defenseCause != null)
                  _ReviewRow(
                    label: "Defense Cause",
                    value: _defenseCause == 'broke'
                        ? "Robot Broke"
                        : "Strategic",
                  ),
                _ReviewRow(label: "Driver Skill", value: "$_skill/5"),
                _ReviewRow(
                  label: "Drivetrain Speed",
                  value: "$_drivetrainSpeed/5",
                ),
                _ReviewRow(label: "Intake Speed", value: "$_intakeSpeed/5"),
                _ReviewRow(label: "Shooter Speed", value: "$_shooterSpeed/5"),
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
                        Icon(
                          Icons.warning,
                          color: colorScheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        Text(
                          "Robot Died",
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_diedAtSeconds != null)
                    _ReviewRow(
                      label: "Died At",
                      value: RobotDiedTimeAndReason.formatMmSs(_diedAtSeconds!),
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
    setState(() => _submitting = true);
    final gameData = {
      'auto_fuel': _autoFuel,
      'auto_tower_l1': _autoTowerL1,
      'teleop_fuel': _teleopFuel,
      'teleop_tower_level': _teleopTower,
      'defense_rating': _defense,
      'defense_cause': _defenseCause,
      'driver_skill': _skill,
      'drivetrain_speed': _drivetrainSpeed,
      'intake_speed': _intakeSpeed,
      'shooter_speed': _shooterSpeed,
      'robot_died': _died,
      'died_at_seconds': _diedAtSeconds,
      'died_reason': _diedReasonCtrl.text,
      'trench_traverse': _trenchTraverse,
      'bump_traverse': _bumpTraverse,
      'shooting_range_close': _shootingRangeClose,
      'shooting_range_mid': _shootingRangeMid,
      'shooting_range_far': _shootingRangeFar,
    };

    final existing = widget.existingMatch;
    final report = existing != null
        ? existing.copyWith(
            matchNumber: int.tryParse(_matchNumberCtrl.text) ?? 0,
            teamNumber: int.tryParse(_teamNumberCtrl.text) ?? 0,
            alliance: _alliance,
            scouterName: _scouterNameCtrl.text,
            // Merge onto the existing map rather than replacing it outright,
            // so any key this form version doesn't know about (a legacy
            // field from an older schema) survives an edit instead of being
            // silently dropped.
            gameData: {...existing.gameData, ...gameData},
            comments: _commentsCtrl.text,
          )
        : MatchReport(
            id: "${widget.eventId}_qm${_matchNumberCtrl.text}_${_teamNumberCtrl.text}",
            matchId: "${widget.eventId}_qm${_matchNumberCtrl.text}",
            matchNumber: int.tryParse(_matchNumberCtrl.text) ?? 0,
            teamNumber: int.tryParse(_teamNumberCtrl.text) ?? 0,
            alliance: _alliance,
            scouterName: _scouterNameCtrl.text,
            gameData: gameData,
            comments: _commentsCtrl.text,
            createdAt: DateTime.now(),
            isSynced: false,
          );

    try {
      final repo = ref.read(firestoreRepositoryProvider);
      if (existing != null) {
        await repo.updateMatch(widget.eventId, report);
      } else {
        await repo.createMatch(widget.eventId, report);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing != null ? "Match Updated!" : "Match Saved!"),
          ),
        );
        // `true` means "a save happened" — not "this was an edit". Both
        // branches above only reach this point after a successful write.
        Navigator.pop(context, true);
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.toUserMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
