import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/task_entity.dart';
import '../providers/task_providers.dart';

class AddTaskDialog extends ConsumerStatefulWidget {
  final TaskEntity? taskToEdit;

  const AddTaskDialog({super.key, this.taskToEdit});

  @override
  ConsumerState<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;
  late final TextEditingController _unitController;

  late TrackingType _type;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    _titleController = TextEditingController(text: t?.title ?? '');
    _targetController = TextEditingController(text: t?.dailyTarget?.toString() ?? '10');
    _unitController = TextEditingController(text: t?.unit ?? 'halaman');
    _type = t?.type ?? TrackingType.binary;
    _selectedColor = t?.color ?? AppTheme.defaultTaskColor;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(taskRepositoryProvider);
    final title = _titleController.text.trim();
    final target = _type == TrackingType.counter ? int.tryParse(_targetController.text) ?? 1 : null;
    final unit = _type == TrackingType.counter ? _unitController.text.trim() : null;

    if (widget.taskToEdit == null) {
      // Create
      await repo.createTask(
        title: title,
        type: _type,
        dailyTarget: target,
        unit: unit,
        color: _selectedColor,
      );
    } else {
      // Update
      await repo.updateTask(
        id: widget.taskToEdit!.id,
        title: title,
        dailyTarget: target,
        unit: unit,
        color: _selectedColor,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskToEdit != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Task' : 'Tambah Task Baru',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 20),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title input
                  const Text('Judul Task', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Misal: Olahraga, Membaca Buku, Coding',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Judul task tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Tracking Type (Disabled if editing to prevent data mismatch)
                  if (!isEditing) ...[
                    const Text('Tipe Tracking', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _typeSelectionCard(
                            type: TrackingType.binary,
                            icon: Icons.check_circle_outline,
                            title: 'Ya / Tidak',
                            subtitle: 'Check-in harian biner',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _typeSelectionCard(
                            type: TrackingType.counter,
                            icon: Icons.add_circle_outline,
                            title: 'Counter',
                            subtitle: 'Target angka harian',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Counter Options
                  if (_type == TrackingType.counter) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Target Harian', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _targetController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  hintText: '10',
                                ),
                                validator: (val) {
                                  if (val == null || int.tryParse(val) == null || int.parse(val) <= 0) {
                                    return 'Target minimal 1';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Satuan (Unit)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _unitController,
                                decoration: const InputDecoration(
                                  hintText: 'halaman, menit, gelas',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Color Picker
                  const Text('Warna Tema Heatmap', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppTheme.taskColors.map((color) {
                      final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _submit,
                        child: Text(isEditing ? 'Simpan Perubahan' : 'Buat Task'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeSelectionCard({
    required TrackingType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _type == type;
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? primaryColor.withValues(alpha: 0.1) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? primaryColor : Colors.grey, size: 22),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? primaryColor : null)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

