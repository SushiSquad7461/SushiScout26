import 'package:flutter/material.dart';
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
