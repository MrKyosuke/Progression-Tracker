import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../progress/data/progress_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/models/task_entity.dart';

// 1. Core Providers
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TaskRepository(db);
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProgressRepository(db, deviceId: 'desktop-windows');
});

// 2. UI State Notifiers (Riverpod 3)
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void set(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// 3. Task Streams
final activeTasksStreamProvider = StreamProvider<List<TaskEntity>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchActiveTasks();
});

final archivedTasksStreamProvider = StreamProvider<List<TaskEntity>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchArchivedTasks();
});

// Filtered Tasks
final filteredActiveTasksProvider = Provider<List<TaskEntity>>((ref) {
  final tasksAsync = ref.watch(activeTasksStreamProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return tasksAsync.when(
    data: (tasks) {
      if (query.isEmpty) return tasks;
      return tasks.where((t) => t.title.toLowerCase().contains(query)).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// 4. Progress Streams
final taskDailyProgressProvider = StreamProvider.family<Map<String, int>, String>((ref, taskId) {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.watchDailyProgress(taskId);
});

final taskTodayCountProvider = StreamProvider.family<int, String>((ref, taskId) {
  final repo = ref.watch(progressRepositoryProvider);
  final todayStr = DateHelper.getLogicalDate();
  return repo.watchCountForDate(taskId, todayStr);
});

final taskStreakProvider = FutureProvider.family<StreakResult, TaskEntity>((ref, task) async {
  final repo = ref.watch(progressRepositoryProvider);
  // Re-run whenever daily progress updates
  ref.watch(taskDailyProgressProvider(task.id));
  return repo.calculateStreakForTask(
    task.id,
    type: task.type,
    dailyTarget: task.dailyTarget,
  );
});
