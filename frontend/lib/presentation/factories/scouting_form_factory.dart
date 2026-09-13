import '../../data/models/event.dart';
import '../../data/models/match_report.dart';
import '../widgets/scouting_form_widget.dart';
import '../screens/frc_rebuilt_form.dart';
import '../screens/ftc_decode_form.dart';

class ScoutingFormFactory {
  static ScoutingFormWidget create(Event event, {MatchReport? existingMatch}) {
    // When editing, the match's own recorded programType is authoritative —
    // the event doc's programType can drift after the match was scored (an
    // admin correction, a stale/offline-fallback Event), and picking the
    // wrong wizard would read the match's gameData through the wrong set of
    // getters and, on save, overwrite it with a wrong-shaped gameData map.
    final programType = existingMatch?.programType ?? event.programType;
    switch (programType) {
      case 'FRC':
        return FrcRebuiltForm(
          eventId: event.id,
          event: event,
          existingMatch: existingMatch,
        );
      case 'FTC':
        return FtcDecodeForm(
          eventId: event.id,
          event: event,
          existingMatch: existingMatch,
        );
      default:
        // Default to FRC or error? Let's default to FRC for safety/legacy
        return FrcRebuiltForm(
          eventId: event.id,
          event: event,
          existingMatch: existingMatch,
        );
    }
  }
}
