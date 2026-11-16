import 'package:drift/drift.dart';

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get type => text()(); // 'binary' | 'counter'
  IntColumn get dailyTarget => integer().nullable()();
  TextColumn get unit => text().nullable()();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()(); // Soft delete for sync

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get color => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class TaskTags extends Table {
  TextColumn get taskId => text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId => text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

/// Append-Only Event Log - single source of truth for all progressions and sync
class ProgressEvents extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get deviceId => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get localDate => text()(); // Logical 'YYYY-MM-DD'
  IntColumn get delta => integer()(); // +1 check-in, -1 undo, +N counter
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Aggregate cache table for rapid heatmap querying and instant UI rendering
class DailyProgressTable extends Table {
  TextColumn get taskId => text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get localDate => text()(); // 'YYYY-MM-DD'
  IntColumn get count => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {taskId, localDate};
}

class AppSettingsTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

