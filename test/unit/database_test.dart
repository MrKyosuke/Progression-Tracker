import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:progression_tracker/core/database/app_database.dart';
import 'package:progression_tracker/features/progress/data/progress_repository.dart';
import 'package:progression_tracker/features/tasks/data/task_repository.dart';
import 'package:progression_tracker/features/tasks/domain/models/task_entity.dart';
import 'package:flutter/material.dart';

void main() {
  late AppDatabase db;
  late TaskRepository taskRepo;
  late ProgressRepository progressRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    taskRepo = TaskRepository(db);
    progressRepo = ProgressRepository(db, deviceId: 'test-device');
  });

  tearDown(() async {
    await db.close();
  });

  test('Creates a binary task and checks in', () async {
    final task = await taskRepo.createTask(
      title: 'Baca Buku',
      type: TrackingType.binary,
      color: Colors.green,
    );

    expect(task.title, 'Baca Buku');
    expect(task.type, TrackingType.binary);

    // Toggle check in
    final count = await progressRepo.toggleBinaryCheckIn(
      taskId: task.id,
      localDate: '2026-11-10',
    );
    expect(count, 1);

    // Toggle undo
    final undoneCount = await progressRepo.toggleBinaryCheckIn(
      taskId: task.id,
      localDate: '2026-11-10',
    );
    expect(undoneCount, 0);
  });

  test('Creates a counter task and increments/decrements', () async {
    final task = await taskRepo.createTask(
      title: 'Minum Air',
      type: TrackingType.counter,
      dailyTarget: 8,
      unit: 'gelas',
      color: Colors.blue,
    );

    expect(task.dailyTarget, 8);

    // Record +3
    final count1 = await progressRepo.recordProgress(
      taskId: task.id,
      localDate: '2026-11-10',
      delta: 3,
    );
    expect(count1, 3);

    // Record +2
    final count2 = await progressRepo.recordProgress(
      taskId: task.id,
      localDate: '2026-11-10',
      delta: 2,
    );
    expect(count2, 5);

    // Undo 1
    final count3 = await progressRepo.undo(
      taskId: task.id,
      localDate: '2026-11-10',
      amount: 1,
    );
    expect(count3, 4);

    // Rebuild cache from event log to ensure source-of-truth integrity
    await db.rebuildDailyProgressCache();

    final cachedRows = await (db.select(db.dailyProgressTable)
          ..where((tbl) => tbl.taskId.equals(task.id)))
        .get();
    expect(cachedRows.first.count, 4);
  });
}

