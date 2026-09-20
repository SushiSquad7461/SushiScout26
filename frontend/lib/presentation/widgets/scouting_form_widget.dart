import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/event.dart';
import '../../data/models/match_report.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';
import 'color_bar.dart';
import 'match_timer.dart';

/// Fixed width for both sides of a wizard's bottom bar. Both
/// [FrcRebuiltForm] and [FtcDecodeForm] wrap their back-button slot and
/// their [ScoutingWizardNextButton] in a [ScoutingWizardBottomSlot] of this
/// width, so [ScoutingWizardPageIndicator] sits at the true center of the
/// bar. Before this constant existed, the back slot was a bare
/// `SizedBox(width: 100)` while the next/submit button sized itself to its
/// label ("next" vs. "submit"/"save") plus an optional spinner — unequal
/// widths pushed the indicator off center.
const double kWizardBottomBarSlotWidth = 112;

/// Wraps [child] in a fixed-width slot, scaling it down rather than letting
/// it overflow if it's ever wider than the slot. See
/// [kWizardBottomBarSlotWidth].
class ScoutingWizardBottomSlot extends StatelessWidget {
  final Widget child;

  const ScoutingWizardBottomSlot({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kWizardBottomBarSlotWidth,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}

/// Drives [PhaseFlashOverlay]: call [flash] with a phase's color to trigger
/// a brief edge glow. Owned by the form screen, with the same lifecycle as
/// [MatchTimerController].
class PhaseFlashController extends ChangeNotifier {
  Color? _color;
  Color? get color => _color;

  void flash(Color color) {
    _color = color;
    notifyListeners();
  }
}

/// Wraps [child] with a brief colored edge glow whenever
/// [controller.flash] fires — the visual cue for a match-phase change. The
/// glow ignores pointer events, so it never blocks the form underneath.
class PhaseFlashOverlay extends StatefulWidget {
  final PhaseFlashController controller;
  final Widget child;

  const PhaseFlashOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<PhaseFlashOverlay> createState() => _PhaseFlashOverlayState();
}

class _PhaseFlashOverlayState extends State<PhaseFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  Color? _flashColor;

  @override
  void initState() {
    super.initState();
    // Created eagerly here, rather than as a `late final` field initializer,
    // so vsync's ancestor lookup runs while the element tree is still
    // active. A lazy initializer would defer creation to whichever access
    // comes first — which, if `flash` is never called, is `dispose()`,
    // after the element has already deactivated.
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    widget.controller.addListener(_handleFlash);
  }

  void _handleFlash() {
    setState(() => _flashColor = widget.controller.color);
    _animation.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleFlash);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_flashColor != null)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => Opacity(
                opacity: 1.0 - _animation.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: _flashColor!, width: 6),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

abstract class ScoutingFormWidget extends ConsumerStatefulWidget {
  final String eventId;
  final Event event;

  /// When non-null, the wizard edits this match in place instead of
  /// submitting a new one: the setup page (scouter/match/team/alliance) is
  /// skipped so those identifying fields can't be changed, and the wizard
  /// writes back via `updateMatch` using this match's original document id.
  final MatchReport? existingMatch;

  const ScoutingFormWidget({
    super.key,
    required this.eventId,
    required this.event,
    this.existingMatch,
  });

  /// Returns the game-specific data Map to be stored in Firestore.
  ///
  /// Each subclass handles its own submission flow (including a review page),
  /// so this is primarily useful for external callers that need to inspect
  /// the current form state via a GlobalKey.
  Map<String, dynamic> collectGameData();
}

/// Mixin that dismisses the keyboard when the user taps outside of a text field.
/// Apply to ConsumerState subclasses of [ScoutingFormWidget].
mixin KeyboardDismissMixin<T extends ScoutingFormWidget> on ConsumerState<T> {
  /// Wrap your Scaffold body with this to dismiss the keyboard on tap outside.
  Widget dismissKeyboardOnTap({required Widget child}) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

/// The brand band shown as an [AppBar.bottom] on every scouting form: the
/// team's colour bar plus the running match timer. Shared by FRC and FTC
/// forms so a future restyle only has to change one widget, and height is
/// derived from [MatchTimer.preferredSize] instead of a hand-copied literal.
class ScoutingFormBrandBand extends StatelessWidget
    implements PreferredSizeWidget {
  final MatchTimerController timerController;
  final ValueChanged<Color>? onPhaseChanged;

  const ScoutingFormBrandBand({
    super.key,
    required this.timerController,
    this.onPhaseChanged,
  });

  @override
  Size get preferredSize => Size.fromHeight(
    MatchTimer(controller: timerController).preferredSize.height +
        AppTheme.colorBarThickness,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorBar(brand: BrandScope.of(context)),
        MatchTimer(controller: timerController, onPhaseChanged: onPhaseChanged),
      ],
    );
  }
}

/// Read-only strip shown at the top of the wizard in edit mode, since the
/// setup page (where this info is normally entered/changed) is skipped — a
/// scout correcting game data shouldn't also be able to reassign the match
/// to a different team or alliance. Shared by FRC and FTC forms so the two
/// copies can't drift.
class ScoutingLockedMatchBanner extends StatelessWidget {
  final String teamNumber;
  final String matchNumber;
  final String alliance;

  const ScoutingLockedMatchBanner({
    super.key,
    required this.teamNumber,
    required this.matchNumber,
    required this.alliance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      color: colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              "Team $teamNumber • Q$matchNumber • $alliance Alliance",
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wizard page-step dots shown in a scouting form's bottom bar. Square,
/// per the design's geometry; the "upcoming" dot uses [ColorScheme.outline]
/// rather than `surfaceContainerHighest`, which is ~(64,64,64) and reads at
/// only 1.5:1 against the near-black bottom bar.
class ScoutingWizardPageIndicator extends StatelessWidget {
  final ColorScheme colorScheme;
  final int currentPage;
  final int pageCount;

  const ScoutingWizardPageIndicator({
    super.key,
    required this.colorScheme,
    required this.currentPage,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(pageCount, (index) {
        final isActive = currentPage == index;
        final isPast = index < currentPage;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : isPast
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outline,
          ),
        );
      }),
    );
  }
}

/// The wizard's Next/Submit action. Label then chevron, per the design's
/// "next ›" — `FilledButton.icon` puts the icon first, which read as
/// "← next", so this hand-builds the row instead.
class ScoutingWizardNextButton extends StatelessWidget {
  final bool isLastPage;
  final bool submitting;
  final VoidCallback? onPressed;
  final String finishLabel;

  const ScoutingWizardNextButton({
    super.key,
    required this.isLastPage,
    required this.submitting,
    required this.onPressed,
    this.finishLabel = "submit",
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: submitting ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isLastPage ? (submitting ? "saving…" : finishLabel) : "next"),
          const SizedBox(width: AppTheme.spacingSm),
          if (submitting)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isLastPage ? Icons.check_rounded : Icons.arrow_forward_rounded,
            ),
        ],
      ),
    );
  }
}
