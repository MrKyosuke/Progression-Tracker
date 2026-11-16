import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../tasks/domain/models/task_entity.dart';

class ProgressRepository {
  final AppDatabase _db;
  final String deviceId;

  ProgressRepository(this._db, {required this.deviceId});

  /// Streams all daily progress entries for a task as a Map of localDate to count
  Stream<Map<String, int>> watchDailyProgress(String taskId) {
    final query = _db.select(_db.dailyProgressTable)
      ..where((tbl) => tbl.taskId.equals(taskId));

    return query.watch().map((rows) {
      final map = <String, int>{};
      for (final r in rows) {
        map[r.localDate] = r.count;
      }
      return map;
    });
  }

  /// Streams today's count for a specific task
  Stream<int> watchCountForDate(String taskId, String localDate) {
    final query = _db.select(_db.dailyProgressTable)
      ..where((tbl) => tbl.taskId.equals(taskId) & tbl.localDate.equals(localDate));

    return query.watchSingleOrNull().map((row) => row?.count ?? 0);
  }

  /// Adds a progression event (+1, +N, or -1 for undo) atomically updating the daily cache
  Future<int> recordProgress({
    required String taskId,
    required String localDate,
    required int delta,
    String? note,
  }) async {
    final eventId = UuidHelper.newId();
    final occurredAt = DateTime.now().toUtc();

    return _db.recordEventAndUpdateCache(
      eventId: eventId,
      taskId: taskId,
      deviceId: deviceId,
      occurredAt: occurredAt,
      localDate: localDate,
      delta: delta,
      note: note,
    );
  }

  /// Toggles binary check-in: if 0 -> +1; if > 0 -> -currentCount (undo to 0)
  Future<int> toggleBinaryCheckIn({
    required String taskId,
    required String localDate,
  }) async {
    final existing = await (_db.select(_db.dailyProgressTable)
          ..where((tbl) => tbl.taskId.equals(taskId) & tbl.localDate.equals(localDate)))
        .getSingleOrNull();

    final current = existing?.count ?? 0;
    if (current == 0) {
      return recordProgress(taskId: taskId, localDate: localDate, delta: 1);
    } else {
      return recordProgress(taskId: taskId, localDate: localDate, delta: -current);
    }
  }

  /// Undo last progression by decrementing 1 (or by specific count)
  Future<int> undo({
    required String taskId,
    required String localDate,
    int amount = 1,
  }) async {
    return recordProgress(taskId: taskId, localDate: localDate, delta: -amount);
  }

  /// Calculates streak for a task
  Future<StreakResult> calculateStreakForTask(
    String taskId, {
    required TrackingType type,
    int? dailyTarget,
    int dayStartHour = 0,
  }) async {
    final target = (type == TrackingType.counter && dailyTarget != null && dailyTarget > 0)
        ? dailyTarget
        : 1;

    final rows = await (_db.select(_db.dailyProgressTable)
          ..where((tbl) => tbl.taskId.equals(taskId) & tbl.count.isBiggerOrEqualValue(target)))
        .get();

    final completedDates = rows.map((r) => r.localDate).toSet();
    return DateHelper.calculateStreak(completedDates, dayStartHour: dayStartHour);
  }
}
