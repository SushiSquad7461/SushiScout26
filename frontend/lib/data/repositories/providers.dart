import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firestore_repository.dart';

/// The team whose data the app is currently showing.
///
/// Overridden in `main.dart` from `currentTeamIdProvider`. Defaults to null so
/// widget tests can construct a container without auth.
final activeTeamIdProvider = Provider<String?>((ref) => null);

/// The app's single data repository.
///
/// Overridden in `main.dart` with a real `FirebaseFirestore` instance scoped to
/// the active team. Firestore's own on-disk persistence is the offline store —
/// there is no second local database.
final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  throw UnimplementedError('Initialize with proper Firebase instance');
});
