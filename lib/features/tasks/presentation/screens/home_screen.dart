import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/date_helper.dart';
import '../../domain/models/task_entity.dart';
import '../providers/task_providers.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/task_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();
  bool _showArchived = false;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openAddTaskDialog() {
    showDialog(
      context: context,
      builder: (_) => const AddTaskDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTasks = ref.watch(filteredActiveTasksProvider);
    final archivedTasksAsync = ref.watch(archivedTasksStreamProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final todayDisplay = DateHelper.formatDisplay(DateTime.now());

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): _openAddTaskDialog,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              // 1. Top Desktop Navigation Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Brand / Logo
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.insights,
                        color: Theme.of(context).primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Progression Tracker',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          todayDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 24),

                    // Search Input (Ctrl+F)
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (val) => ref.read(searchQueryProvider.notifier).set(val),
                        decoration: InputDecoration(
                          hintText: 'Cari task... (Ctrl + F)',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(searchQueryProvider.notifier).set('');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Archive Tab Toggle
                    TextButton.icon(
                      onPressed: () => setState(() => _showArchived = !_showArchived),
                      icon: Icon(_showArchived ? Icons.arrow_back : Icons.archive_outlined, size: 16),
                      label: Text(_showArchived ? 'Kembali' : 'Arsip', style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Theme Toggle
                    IconButton(
                      tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
                      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
                      onPressed: () {
                        ref.read(themeModeProvider.notifier).toggle();
                      },
                    ),

                    const SizedBox(width: 8),

                    // Add Task Button (Shortcut: N)
                    ElevatedButton.icon(
                      onPressed: _openAddTaskDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Row(
                        children: [
                          Text('Task Baru', style: TextStyle(fontSize: 13)),
                          SizedBox(width: 4),
                          Text(
                            '[N]',
                            style: TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Main Content Area
              Expanded(
                child: _showArchived
                    ? _buildArchivedView(archivedTasksAsync)
                    : _buildActiveView(activeTasks),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveView(List<TaskEntity> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt,
                size: 54,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum ada task aktif',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Mulai bangun kebiasaan harian dengan membuat task pertama Anda.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openAddTaskDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Buat Task Pertama'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return TaskCard(
          key: ValueKey(tasks[index].id),
          task: tasks[index],
        );
      },
    );
  }

  Widget _buildArchivedView(AsyncValue<List<TaskEntity>> archivedAsync) {
    final archived = archivedAsync.value ?? [];

    if (archived.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada task yang diarsipkan',
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      itemCount: archived.length,
      itemBuilder: (context, index) {
        final task = archived[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: task.color,
              radius: 12,
            ),
            title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Tipe: ${task.type.displayName}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.unarchive, size: 16),
                  label: const Text('Pulihkan'),
                  onPressed: () async {
                    await ref.read(taskRepositoryProvider).setArchived(task.id, false);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  tooltip: 'Hapus Permanen',
                  onPressed: () async {
                    await ref.read(taskRepositoryProvider).softDelete(task.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
