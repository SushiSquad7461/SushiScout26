import '../models/event.dart';
import '../models/match_report.dart';

abstract class ScoutingRepository {
  Stream<List<MatchReport>> watchMatches(String eventId);
  Stream<List<MatchReport>> watchTrash(String eventId);
  Future<void> createMatch(String eventId, MatchReport match);
  Future<void> updateMatch(String eventId, MatchReport match);
  Future<void> trashMatch(String eventId, String matchId);
  Future<void> restoreMatch(String eventId, String matchId);
  Future<void> deleteMatch(String eventId, String matchId);
  Future<List<MatchReport>> getMatches(String eventId);
  Future<Event?> getEvent(String eventId);
  Future<List<Event>> getEvents();
}
