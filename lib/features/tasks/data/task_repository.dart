import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/uuid_helper.dart';
import '../domain/models/task_entity.dart';

class TaskRepository {
  final AppDatabase _db;

  TaskRepository(this._db);

  TaskEntity _toEntity(Task row) {
    return TaskEntity(
      id: row.id,
      title: row.title,
      type: TrackingType.fromString(row.type),
      dailyTarget: row.dailyTarget,
      unit: row.unit,
      color: Color(row.color),
      sortOrder: row.sortOrder,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  /// Streams active (non-archived and non-deleted) tasks
  Stream<List<TaskEntity>> watchActiveTasks() {
    final query = _db.select(_db.tasks)
      ..where((tbl) => tbl.isArchived.equals(false) & tbl.deletedAt.isNull())
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.sortOrder, mode: OrderingMode.asc),
        (tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  /// Streams archived tasks
  Stream<List<TaskEntity>> watchArchivedTasks() {
    final query = _db.select(_db.tasks)
      ..where((tbl) => tbl.isArchived.equals(true) & tbl.deletedAt.isNull())
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  Future<TaskEntity> createTask({
    required String title,
    required TrackingType type,
    int? dailyTarget,
    String? unit,
    required Color color,
  }) async {
    final now = DateTime.now().toUtc();
    final id = UuidHelper.newId();

    final companion = TasksCompanion.insert(
      id: id,
      title: title,
      type: type.name,
      dailyTarget: Value(type == TrackingType.counter ? (dailyTarget ?? 1) : null),
      unit: Value(type == TrackingType.counter ? unit : null),
      color: color.toARGB32(),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.tasks).insert(companion);

    return TaskEntity(
      id: id,
      title: title,
      type: type,
      dailyTarget: dailyTarget,
      unit: unit,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateTask({
    required String id,
    required String title,
    int? dailyTarget,
    String? unit,
    required Color color,
  }) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(id))).write(
      TasksCompanion(
        title: Value(title),
        dailyTarget: Value(dailyTarget),
        unit: Value(unit),
        color: Value(color.toARGB32()),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> setArchived(String id, bool isArchived) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(id))).write(
      TasksCompanion(
        isArchived: Value(isArchived),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(id))).write(
      TasksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }
}

