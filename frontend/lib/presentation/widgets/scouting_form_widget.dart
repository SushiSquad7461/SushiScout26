import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/event.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';
import 'color_bar.dart';
import 'match_timer.dart';

abstract class ScoutingFormWidget extends ConsumerStatefulWidget {
  final String eventId;
  final Event event;

  const ScoutingFormWidget({
    super.key,
    required this.eventId,
    required this.event,
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

  const ScoutingFormBrandBand({super.key, required this.timerController});

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
        MatchTimer(controller: timerController),
      ],
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

  const ScoutingWizardNextButton({
    super.key,
    required this.isLastPage,
    required this.submitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: submitting ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isLastPage ? (submitting ? "saving…" : "submit") : "next"),
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
