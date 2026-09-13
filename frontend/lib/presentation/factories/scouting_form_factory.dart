import '../../data/models/event.dart';
import '../../data/models/match_report.dart';
import '../widgets/scouting_form_widget.dart';
import '../screens/frc_rebuilt_form.dart';
import '../screens/ftc_decode_form.dart';

class ScoutingFormFactory {
  static ScoutingFormWidget create(Event event, {MatchReport? existingMatch}) {
    switch (event.programType) {
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
