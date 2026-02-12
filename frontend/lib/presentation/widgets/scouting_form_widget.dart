import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/event.dart';

abstract class ScoutingFormWidget extends ConsumerStatefulWidget {
  final String eventId;
  final Event event;

  const ScoutingFormWidget({
    super.key,
    required this.eventId,
    required this.event,
  });

  /// Returns the game-specific data Map to be stored in Firestore
  // Note: This needs to be accessible via GlobalKey or similar if calling from parent,
  // OR the widget itself handles submission.
  // Design decision: The widget itself should handle its own "Review & Submit" page
  // because the review page is highly game-specific.
  // So this method might not be strictly necessary publicly if the form handles its own submission.
  // But strictly per architecture doc:
  Map<String, dynamic> collectGameData();
}
