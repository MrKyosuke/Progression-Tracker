import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Tasks,
    Tags,
    TaskTags,
    ProgressEvents,
    DailyProgressTable,
    AppSettingsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'progression_tracker');
  }

  // --- Helpers for Transactions & Atomic Aggregation ---

  /// Records a progress event and immediately updates the DailyProgress cache table atomically
  Future<int> recordEventAndUpdateCache({
    required String eventId,
    required String taskId,
    required String deviceId,
    required DateTime occurredAt,
    required String localDate,
    required int delta,
    String? note,
  }) {
    return transaction(() async {
      // 1. Insert into append-only event log
      await into(progressEvents).insert(
        ProgressEventsCompanion.insert(
          id: eventId,
          taskId: taskId,
          deviceId: deviceId,
          occurredAt: occurredAt,
          localDate: localDate,
          delta: delta,
          note: Value(note),
        ),
      );

      // 2. Fetch existing daily progress count
      final existing = await (select(dailyProgressTable)
            ..where((tbl) => tbl.taskId.equals(taskId) & tbl.localDate.equals(localDate)))
          .getSingleOrNull();

      final currentCount = existing?.count ?? 0;
      final newCount = (currentCount + delta) < 0 ? 0 : (currentCount + delta);

      // 3. Upsert into daily progress cache
      await into(dailyProgressTable).insertOnConflictUpdate(
        DailyProgressTableCompanion.insert(
          taskId: taskId,
          localDate: localDate,
          count: Value(newCount),
        ),
      );

      return newCount;
    });
  }

  /// Rebuilds the entire DailyProgress cache table from the event log (source of truth)
  Future<void> rebuildDailyProgressCache() {
    return transaction(() async {
      await delete(dailyProgressTable).go();

      final query = customSelect(
        'SELECT task_id, local_date, SUM(delta) as total '
        'FROM progress_events '
        'GROUP BY task_id, local_date',
        readsFrom: {progressEvents},
      );

      final rows = await query.get();
      for (final row in rows) {
        final taskId = row.read<String>('task_id');
        final localDate = row.read<String>('local_date');
        final total = row.read<int>('total');
        if (total > 0) {
          await into(dailyProgressTable).insert(
            DailyProgressTableCompanion.insert(
              taskId: taskId,
              localDate: localDate,
              count: Value(total),
            ),
          );
        }
      }
    });
  }
}

