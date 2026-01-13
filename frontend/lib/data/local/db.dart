import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'db.g.dart';

class MatchEntries extends Table {
  TextColumn get id => text()();

  // Event Context
  TextColumn get eventCode => text()();
  IntColumn get matchNumber => integer()();
  IntColumn get teamNumber => integer()();
  TextColumn get alliance => text()(); // 'Red' or 'Blue'
  TextColumn get scouterName => text()();

  // Auto
  IntColumn get autoFuel => integer().withDefault(const Constant(0))();
  BoolColumn get autoTowerL1 => boolean().withDefault(const Constant(false))();

  // Teleop
  IntColumn get teleopFuel => integer().withDefault(const Constant(0))();
  IntColumn get teleopTowerLevel =>
      integer().withDefault(const Constant(0))(); // 0-3

  // Qualitative
  IntColumn get defenseRating => integer().withDefault(const Constant(0))();
  IntColumn get driverSkill => integer().withDefault(const Constant(0))();
  BoolColumn get robotDied => boolean().withDefault(const Constant(false))();
  TextColumn get comments => text().withDefault(const Constant(''))();

  // Sync Status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [MatchEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'sushi_scout_26_db');
  }
}
