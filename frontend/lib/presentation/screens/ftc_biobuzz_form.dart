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

/// FTC 2026-27 "BIOBUZZ" scouting form with Material 3 styling.
///
/// Robots launch POLLEN and NECTAR into the HIVE to tip it, score in the
/// FLOWERS on the wall, and PARK in the loading zone at match end.
class FtcBioBuzzForm extends ScoutingFormWidget {
  const FtcBioBuzzForm({
    super.key,
    required super.eventId,
    required super.event,
    super.existingMatch,
  });

  @override
  ConsumerState<FtcBioBuzzForm> createState() => _FtcBioBuzzFormState();

  @override
  Map<String, dynamic> collectGameData() => {};
}

class _FtcBioBuzzFormState extends ConsumerState<FtcBioBuzzForm>
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

  // FTC BIOBUZZ Fields
  // Auto
  bool _leave = false;
  int _autoHiveTips = 0;

  // Teleop
  int _teleHiveTips = 0;
  bool _flowerScore = false;
  bool _flowerDescore = false;
  bool _pollenShooter = false;
  bool _nectarShooter = false;
  bool _robotDied = false;
  int? _diedAtSeconds;
  final _diedReasonCtrl = TextEditingController();

  // Endgame
  bool _park = false;
  double _driverQuality = 0;
  int _defenseRating = 0;
  String? _defenseCause;
  int _drivetrainSpeed = 0;
  int _intakeSpeed = 0;
  int _shooterSpeed = 0;
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
      _leave = existing.leave;
      _autoHiveTips = existing.hiveTipsAuto;
      _teleHiveTips = existing.hiveTipsTeleop;
      _flowerScore = existing.flowerScore;
      _flowerDescore = existing.flowerDescore;
      _pollenShooter = existing.pollenShooter;
      _nectarShooter = existing.nectarShooter;
      _robotDied = existing.robotDied;
      _diedAtSeconds = existing.diedAtSeconds;
      _diedReasonCtrl.text = existing.diedReason;
      _park = existing.park;
      _driverQuality = existing.driverQuality;
      _defenseRating = existing.defenseRating;
      _defenseCause = existing.defenseCause;
      _drivetrainSpeed = existing.drivetrainSpeed;
      _intakeSpeed = existing.intakeSpeed;
      _shooterSpeed = existing.shooterSpeed;
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
                // BIOBUZZ: 30s auto, 8s transition, 2:00 teleop.
                timing: MatchTiming.ftc,
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

          _buildPageIndicator(colorScheme),

          const Spacer(),

          // Label then chevron, per the design's "next ›" — FilledButton.icon
          // puts the icon first, which read as "← next".
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
          Expanded(
            child: SingleChildScrollView(
              // Room for an outlined field's floating label, which sits
              // half above the field and clips at the scroll area's edge.
              padding: const EdgeInsets.only(top: AppTheme.spacingSm),
              child: content,
            ),
          ),
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
                  errorMaxLines: 3,
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
                  errorMaxLines: 3,
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
    return Column(
      children: [
        Card(
          child: CheckboxListTile(
            title: const Text("Leave Start Area"),
            subtitle: const Text("Robot left the starting zone"),
            value: _leave,
            onChanged: (v) => setState(() => _leave = v!),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),

        const SizedBox(height: AppTheme.spacingMd),

        CounterCard(
          label: "Auto Hive Tips",
          helperText: "Times the hive tipped during autonomous",
          value: _autoHiveTips,
          onChanged: (v) => setState(() => _autoHiveTips = v),
          accentColor: Theme.of(context).colorScheme.tertiary,
        ),
      ],
    );
  }

  Widget _buildTeleop(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        CounterCard(
          label: "Teleop Hive Tips",
          helperText: "Times the hive tipped during teleop",
          value: _teleHiveTips,
          onChanged: (v) => setState(() => _teleHiveTips = v),
        ),

        const SizedBox(height: AppTheme.spacingMd),

        Card(
          color: _robotDied
              ? colorScheme.errorContainer.withValues(alpha: 0.5)
              : null,
          child: Column(
            children: [
              CheckboxListTile(
                title: Text(
                  "Robot Died / Disabled",
                  style: TextStyle(
                    color: _robotDied ? colorScheme.error : null,
                  ),
                ),
                subtitle: const Text("Robot was inactive during match"),
                value: _robotDied,
                onChanged: (v) => setState(() {
                  _robotDied = v!;
                  if (!_robotDied) {
                    _diedAtSeconds = null;
                    _diedReasonCtrl.clear();
                  }
                }),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_robotDied)
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

        // Same heading-over-card layout as the FRC form's Mobility and
        // Shooting Range groups.
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Capabilities",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),

        Card(
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text("Can Score Flowers"),
                subtitle: const Text("Places pollen or nectar in a flower"),
                value: _flowerScore,
                onChanged: (v) => setState(() => _flowerScore = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                title: const Text("Can Descore Flowers"),
                subtitle: const Text("Removes pollen through a flower's base"),
                value: _flowerDescore,
                onChanged: (v) => setState(() => _flowerDescore = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                title: const Text("Pollen Shooter"),
                subtitle: const Text("Launches pollen into the hive"),
                value: _pollenShooter,
                onChanged: (v) => setState(() => _pollenShooter = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                title: const Text("Nectar Shooter"),
                subtitle: const Text("Launches nectar into the hive"),
                value: _nectarShooter,
                onChanged: (v) => setState(() => _nectarShooter = v!),
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
        Card(
          child: CheckboxListTile(
            title: const Text("Park"),
            subtitle: const Text("Robot parked in the loading zone at the end"),
            value: _park,
            onChanged: (v) => setState(() => _park = v!),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),

        const SizedBox(height: AppTheme.spacingLg),

        Text("Qualitative Metrics", style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingMd),

        _buildSlider(
          context,
          label: "Driver Quality",
          value: _driverQuality.toInt(),
          onChanged: (v) => setState(() => _driverQuality = v.toDouble()),
        ),

        _buildSlider(
          context,
          label: "Defense Rating",
          value: _defenseRating,
          onChanged: (v) => setState(() {
            _defenseRating = v;
            if (v == 0) _defenseCause = null;
          }),
        ),

        if (_defenseRating > 0)
          DefenseCauseSelector(
            cause: _defenseCause,
            onChanged: (v) => setState(() => _defenseCause = v),
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
                _ReviewRow(label: "Leave", value: _leave ? "Yes" : "No"),
                _ReviewRow(label: "Auto Hive Tips", value: "$_autoHiveTips"),
                const Divider(height: AppTheme.spacingLg),
                _ReviewRow(label: "Teleop Hive Tips", value: "$_teleHiveTips"),
                _ReviewRow(
                  label: "Can Score Flowers",
                  value: _flowerScore ? "Yes" : "No",
                ),
                _ReviewRow(
                  label: "Can Descore Flowers",
                  value: _flowerDescore ? "Yes" : "No",
                ),
                _ReviewRow(
                  label: "Pollen Shooter",
                  value: _pollenShooter ? "Yes" : "No",
                ),
                _ReviewRow(
                  label: "Nectar Shooter",
                  value: _nectarShooter ? "Yes" : "No",
                ),
                const Divider(height: AppTheme.spacingLg),
                _ReviewRow(label: "Park", value: _park ? "Yes" : "No"),
                _ReviewRow(
                  label: "Driver Quality",
                  value: "${_driverQuality.toInt()}/5",
                ),
                _ReviewRow(label: "Defense Rating", value: "$_defenseRating/5"),
                if (_defenseCause != null)
                  _ReviewRow(
                    label: "Defense Cause",
                    value: _defenseCause == 'broke'
                        ? "Robot Broke"
                        : "Strategic",
                  ),
                _ReviewRow(
                  label: "Drivetrain Speed",
                  value: "$_drivetrainSpeed/5",
                ),
                _ReviewRow(label: "Intake Speed", value: "$_intakeSpeed/5"),
                _ReviewRow(label: "Shooter Speed", value: "$_shooterSpeed/5"),
                if (_robotDied) ...[
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
      'leave': _leave,
      'hive_tips_auto': _autoHiveTips,
      'hive_tips_teleop': _teleHiveTips,
      'flower_score': _flowerScore,
      'flower_descore': _flowerDescore,
      'pollen_shooter': _pollenShooter,
      'nectar_shooter': _nectarShooter,
      'park': _park,
      'driver_quality': _driverQuality,
      'defense_rating': _defenseRating,
      'defense_cause': _defenseCause,
      'drivetrain_speed': _drivetrainSpeed,
      'intake_speed': _intakeSpeed,
      'shooter_speed': _shooterSpeed,
      'robot_died': _robotDied,
      'died_at_seconds': _diedAtSeconds,
      'died_reason': _diedReasonCtrl.text,
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
            // This wizard only ever produces FTC-shaped gameData. Without
            // this, MatchReport defaults to FRC, and the repository copies
            // that into a brand-new event doc on the first save.
            programType: 'FTC',
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
            content: Text(
              existing != null ? "Match Updated!" : "FTC Match Saved!",
            ),
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
