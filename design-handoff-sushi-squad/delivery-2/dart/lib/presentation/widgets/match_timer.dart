import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/animations.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';

/// Match timer.
///
/// **This widget is mounted as `AppBar(bottom: MatchTimer(...))` by both
/// scouting forms, so it sits INSIDE the app bar.** The app bar is "chrome" —
/// ink in both brightnesses (see [AppTheme.chrome]) — so every colour in here
/// must be read from the chrome pair, never from `colorScheme.surface` /
/// `onSurface`.
///
/// Painting it from the surface pair is what broke light mode: `surface` is
/// white in light mode, so the timer rendered as a white slab wedged inside the
/// black app bar, and the phase chip (fill `onSurface` = black, label hardcoded
/// `brand.ink` = black) came out as an empty black box.
///
/// All timer behaviour below — durations, phase thresholds, haptics, the
/// controller, `onMatchFinished` — is unchanged.
class MatchTimerController extends ChangeNotifier {
  void start() {
    notifyListeners();
  }
}

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

  /// The chip fill for the current phase. Every value here is chosen to sit on
  /// ink chrome, and the chip's label colour is derived from it by luminance —
  /// so ENDGAME's dark red gets a white label rather than a black one.
  Color _phaseFill(TeamBrand brand, ColorScheme colorScheme) {
    switch (_currentPhase) {
      case "AUTO":
        return brand.accentHighlight; // french
      case "TELEOP":
        return AppTheme.onChrome(brand); // paper, in both brightnesses
      case "ENDGAME":
        return colorScheme.error;
      case "FINISHED":
        return colorScheme.error;
      default:
        return AppTheme.mutedOnChrome(brand);
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

    // Chrome, not surface — this widget lives inside the app bar.
    final chrome = AppTheme.chrome(brand);
    final onChrome = AppTheme.onChrome(brand);

    final phaseFill = _phaseFill(brand, colorScheme);
    // A thin progress line or a 28dp icon in #c10000 on black is 2.2:1, so the
    // line and the icon step up to paper when the fill is too dark to read;
    // the chip keeps the true phase colour.
    final phaseAccent = AppTheme.legibleOn(chrome, phaseFill, onChrome);

    final minutes = _secondsRemaining ~/ 60;
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final progress = 1.0 - (_secondsRemaining / _totalDuration);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: chrome,
        border: Border(
          bottom: BorderSide(color: onChrome, width: AppTheme.ruleWidth),
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
                valueColor: AlwaysStoppedAnimation<Color>(phaseAccent),
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
                        foregroundColor: phaseAccent,
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
                          foregroundColor: AppTheme.mutedOnChrome(brand),
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
                      decoration: BoxDecoration(color: phaseFill),
                      child: Text(
                        _currentPhase,
                        style: theme.textTheme.labelMedium?.copyWith(
                          // Derived from the fill, so it can never come out
                          // black-on-black or black-on-dark-red.
                          color: AppTheme.onFill(brand, phaseFill),
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
                      child: Text(
                        '$minutes:$seconds',
                        style: AppTheme.display(
                          brand,
                          size: 24,
                          letterSpacing: 0.02,
                          color: onChrome,
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
