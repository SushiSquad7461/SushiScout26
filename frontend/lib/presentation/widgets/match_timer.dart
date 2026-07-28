import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/animations.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';

/// Controller for programmatically starting the match timer.
class MatchTimerController extends ChangeNotifier {
  void start() {
    notifyListeners();
  }
}

/// Material 3 styled match timer widget.
///
/// Features:
/// - Visual phase indicator (Auto, Teleop, Endgame)
/// - M3 color tokens for phase colors
/// - Linear progress indicator
/// - 48dp minimum touch targets for controls
/// - Visible reset button when timer is running or paused mid-match
/// - Haptic feedback on start, pause, and reset
/// - Semantic labels for accessibility
class MatchTimer extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback? onMatchFinished;
  final MatchTimerController? controller;

  const MatchTimer({super.key, this.onMatchFinished, this.controller});

  @override
  State<MatchTimer> createState() => _MatchTimerState();

  @override
  Size get preferredSize => const Size.fromHeight(64);
}

class _MatchTimerState extends State<MatchTimer> {
  Timer? _timer;
  int _secondsRemaining = 135; // 2:15 total duration
  bool _isRunning = false;
  static const int _totalDuration = 135;

  String get _currentPhase {
    if (!_isRunning && _secondsRemaining == _totalDuration) return "PRE-MATCH";
    if (_secondsRemaining > 120) return "AUTO"; // First 15s
    if (_secondsRemaining <= 0) return "FINISHED";
    if (_secondsRemaining <= 30) return "ENDGAME"; // Last 30s
    return "TELEOP";
  }

  /// Whether the timer has been started at least once (not at initial state).
  bool get _hasStarted => _isRunning || _secondsRemaining != _totalDuration;

  Color _getPhaseColor(TeamBrand brand, ColorScheme colorScheme) {
    switch (_currentPhase) {
      case "AUTO":
        return brand.accentHighlight; // french
      case "TELEOP":
        return colorScheme.onSurface;
      case "ENDGAME":
        return colorScheme.error;
      case "FINISHED":
        return colorScheme.error;
      default:
        return colorScheme.outline;
    }
  }

  Color _getPhaseContainerColor(ColorScheme colorScheme) {
    switch (_currentPhase) {
      case "AUTO":
        return colorScheme.tertiaryContainer;
      case "TELEOP":
        return colorScheme.primaryContainer;
      case "ENDGAME":
        return colorScheme.errorContainer;
      case "FINISHED":
        return colorScheme.errorContainer;
      default:
        return colorScheme.surfaceContainerHighest;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_handleControllerStart);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerStart);
    _timer?.cancel();
    super.dispose();
  }

  void _handleControllerStart() {
    if (!_isRunning && _secondsRemaining == _totalDuration) {
      _startTimer();
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      _stopTimer();
      AppHaptics.light();
    } else {
      if (_secondsRemaining <= 0) _resetTimer();
      _startTimer();
      AppHaptics.medium();
    }
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _stopTimer();
        AppHaptics.heavy();
        widget.onMatchFinished?.call();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    if (mounted) setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _stopTimer();
    AppHaptics.error();
    if (mounted) setState(() => _secondsRemaining = _totalDuration);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brand = BrandScope.of(context);
    final phaseColor = _getPhaseColor(brand, colorScheme);
    final containerColor = _getPhaseContainerColor(colorScheme);

    final minutes = _secondsRemaining ~/ 60;
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final progress = 1.0 - (_secondsRemaining / _totalDuration);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: containerColor.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Progress indicator
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                minHeight: 4,
              );
            },
          ),

          // Controls row
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
              ),
              child: Row(
                children: [
                  // Play/Pause button (48dp minimum)
                  Semantics(
                    label: _isRunning
                        ? 'Pause match timer'
                        : _secondsRemaining <= 0
                        ? 'Restart match timer'
                        : 'Start match timer',
                    button: true,
                    child: IconButton(
                      onPressed: _toggleTimer,
                      icon: Icon(
                        _isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      iconSize: 28,
                      style: IconButton.styleFrom(
                        foregroundColor: phaseColor,
                        minimumSize: const Size(48, 48),
                      ),
                      tooltip: _isRunning ? "Pause" : "Start",
                    ),
                  ),

                  // Reset button — visible when timer has been used
                  if (_hasStarted)
                    Semantics(
                      label: 'Reset match timer to 2 minutes 15 seconds',
                      button: true,
                      child: IconButton(
                        onPressed: _resetTimer,
                        icon: const Icon(Icons.replay_rounded),
                        iconSize: 22,
                        style: IconButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                          minimumSize: const Size(48, 48),
                        ),
                        tooltip: "Reset",
                      ),
                    ),

                  const SizedBox(width: AppTheme.spacingSm),

                  // Phase label
                  Semantics(
                    label:
                        'Current match phase: ${_currentPhase.toLowerCase()}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSm,
                        vertical: AppTheme.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: phaseColor,
                        borderRadius: BorderRadius.circular(AppTheme.spacingSm),
                      ),
                      child: Text(
                        _currentPhase,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: brand.ink,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Timer display
                  Semantics(
                    label:
                        '$minutes minutes and ${_secondsRemaining % 60} seconds remaining',
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                        vertical: AppTheme.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
                      ),
                      child: Text.rich(
                        AppTheme.displayRun(
                          brand,
                          ['$minutes', seconds],
                          separator: ':',
                          size: 24,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
