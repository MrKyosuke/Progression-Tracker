import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../progress/presentation/widgets/heatmap_view.dart';
import '../../domain/models/task_entity.dart';
import '../providers/task_providers.dart';
import 'add_task_dialog.dart';

class TaskCard extends ConsumerWidget {
  final TaskEntity task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyProgressAsync = ref.watch(taskDailyProgressProvider(task.id));
    final todayCountAsync = ref.watch(taskTodayCountProvider(task.id));
    final streakAsync = ref.watch(taskStreakProvider(task));

    final todayCount = todayCountAsync.value ?? 0;
    final dailyCounts = dailyProgressAsync.value ?? {};
    final isDoneToday = todayCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title, Badges, Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Color accent bar
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: task.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),

                // Title and badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          _buildStreakBadge(context, streakAsync),
                          const SizedBox(width: 8),
                          _buildOptionsMenu(context, ref),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildTypeBadge(context),
                          if (task.type == TrackingType.counter)
                            _buildTargetBadge(context),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Middle Action Row: Fast Check-in Controls
            _buildCheckInControl(context, ref, todayCount, isDoneToday),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Heatmap Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aktivitas 365 Hari',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '${dailyCounts.values.where((c) => c > 0).length} hari aktif',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 365-day Heatmap Canvas
            HeatmapView(
              task: task,
              dailyCounts: dailyCounts,
              onCellTapped: (dateStr) {
                _showBackfillDialog(context, ref, dateStr, dailyCounts[dateStr] ?? 0);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInControl(
    BuildContext context,
    WidgetRef ref,
    int todayCount,
    bool isDoneToday,
  ) {
    final progressRepo = ref.read(progressRepositoryProvider);
    final todayStr = DateHelper.getLogicalDate();

    if (task.type == TrackingType.binary) {
      // Binary Check-in (Done / Undone)
      return Row(
        children: [
          InkWell(
            onTap: () async {
              await progressRepo.toggleBinaryCheckIn(
                taskId: task.id,
                localDate: todayStr,
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDoneToday ? task.color : task.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDoneToday ? task.color : task.color.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDoneToday ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isDoneToday ? Colors.white : task.color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDoneToday ? 'Selesai Hari Ini' : 'Check-in Hari Ini',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDoneToday ? Colors.white : task.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isDoneToday) ...[
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: () async {
                await progressRepo.undo(taskId: task.id, localDate: todayStr);
              },
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Undo', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      );
    } else {
      // Counter Check-in (Minus / Progress / Plus)
      final target = task.dailyTarget ?? 1;
      final unit = task.unit ?? '';
      final percent = ((todayCount / target) * 100).clamp(0, 100).toInt();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Minus button
              IconButton(
                onPressed: todayCount > 0
                    ? () async {
                        await progressRepo.recordProgress(
                          taskId: task.id,
                          localDate: todayStr,
                          delta: -1,
                        );
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 24,
                tooltip: 'Kurangi 1',
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),

              // Counter text display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$todayCount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: todayCount >= target ? task.color : null,
                      ),
                    ),
                    Text(
                      ' / $target $unit',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '($percent%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: todayCount >= target ? task.color : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Plus button
              IconButton(
                onPressed: () async {
                  await progressRepo.recordProgress(
                    taskId: task.id,
                    localDate: todayStr,
                    delta: 1,
                  );
                },
                icon: const Icon(Icons.add_circle),
                iconSize: 26,
                tooltip: 'Tambah 1',
                color: task.color,
              ),

              const SizedBox(width: 8),

              // Quick +5 button for efficiency
              OutlinedButton(
                onPressed: () async {
                  await progressRepo.recordProgress(
                    taskId: task.id,
                    localDate: todayStr,
                    delta: 5,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  side: BorderSide(color: task.color.withValues(alpha: 0.5)),
                ),
                child: Text('+5', style: TextStyle(fontSize: 12, color: task.color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (todayCount / target).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(task.color),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildStreakBadge(BuildContext context, AsyncValue<StreakResult> streakAsync) {
    final streak = streakAsync.value?.currentStreak ?? 0;
    final longest = streakAsync.value?.longestStreak ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: streak > 0
            ? Colors.orange.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: streak > 0 ? Colors.orange.withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(streak > 0 ? '🔥' : '❄️', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$streak hari streak',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: streak > 0 ? Colors.orange : Colors.grey,
            ),
          ),
          if (longest > streak) ...[
            const SizedBox(width: 4),
            Text(
              '(Rekor: $longest)',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        task.type == TrackingType.binary ? 'Binary' : 'Counter',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildTargetBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: task.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Target: ${task.dailyTarget} ${task.unit ?? ''}/hari',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: task.color,
        ),
      ),
    );
  }

  Widget _buildOptionsMenu(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      tooltip: 'Opsi Task',
      onSelected: (val) async {
        if (val == 'edit') {
          showDialog(
            context: context,
            builder: (_) => AddTaskDialog(taskToEdit: task),
          );
        } else if (val == 'archive') {
          await ref.read(taskRepositoryProvider).setArchived(task.id, true);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Task "${task.title}" diarsipkan')),
            );
          }
        } else if (val == 'delete') {
          _confirmDelete(context, ref);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16),
              SizedBox(width: 8),
              Text('Edit Task', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              Icon(Icons.archive_outlined, size: 16),
              SizedBox(width: 8),
              Text('Arsipkan', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Hapus', style: TextStyle(fontSize: 13, color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Task?'),
        content: Text('Yakin ingin menghapus task "${task.title}"? Data progress akan tetap disimpan untuk kebutuhan sync.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(taskRepositoryProvider).softDelete(task.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showBackfillDialog(BuildContext context, WidgetRef ref, String dateStr, int currentCount) {
    final controller = TextEditingController(text: currentCount.toString());
    final date = DateHelper.parseYmd(dateStr);
    final formattedDate = DateHelper.formatDisplay(date);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Progress ($formattedDate)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Atur jumlah progress untuk task "${task.title}":'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: task.type == TrackingType.binary ? 'Status (1 = Selesai, 0 = Belum)' : 'Jumlah (${task.unit ?? ''})',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCount = int.tryParse(controller.text) ?? 0;
              final delta = newCount - currentCount;
              if (delta != 0) {
                await ref.read(progressRepositoryProvider).recordProgress(
                  taskId: task.id,
                  localDate: dateStr,
                  delta: delta,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

