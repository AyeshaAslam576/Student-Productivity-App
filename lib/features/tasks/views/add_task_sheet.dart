import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_chip.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../models/task_model.dart';
import '../viewmodels/task_viewmodel.dart';

void showAddTaskSheet(
  BuildContext context,
  TaskViewModel vm, {
  TaskModel? initialTask,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: vm,
      child: AddTaskSheet(initialTask: initialTask),
    ),
  );
}

class AddTaskSheet extends StatefulWidget {
  final TaskModel? initialTask;

  const AddTaskSheet({super.key, this.initialTask});

  bool get isEditing => initialTask != null;

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _subtaskCtrl = TextEditingController();
  late DateTime _dueDate;
  late String _type;
  late String _priority;
  final List<SubTask> _subtasks = [];
  late bool _hasReminder;
  DateTime? _reminderTime;
  bool _submitting = false;

  final _types = [
    'Assignment',
    'Quiz',
    'Project',
    'Homework',
    'Exam',
    'Lab',
    'Presentation',
    'Other',
  ];
  final _priorities = ['Low', 'Medium', 'High', 'Critical'];

  @override
  void initState() {
    super.initState();
    final t = widget.initialTask;
    if (t != null) {
      _titleCtrl.text = t.title;
      _subjectCtrl.text = t.subject;
      _descCtrl.text = t.description ?? '';
      _dueDate = t.dueDate;
      _type = _types.firstWhere(
        (x) => x.toLowerCase() == t.type.name.toLowerCase(),
        orElse: () => 'Other',
      );
      _priority = _priorities.firstWhere(
        (x) => x.toLowerCase() == t.priority.name.toLowerCase(),
        orElse: () => 'Medium',
      );
      _subtasks.addAll(t.subtasks);
      _hasReminder = t.hasReminder;
      _reminderTime =
          t.reminderTime ?? t.dueDate.subtract(const Duration(hours: 24));
    } else {
      _dueDate = DateTime.now().add(const Duration(days: 1));
      _type = 'Assignment';
      _priority = 'Medium';
      _hasReminder = true;
      _reminderTime = _dueDate.subtract(const Duration(hours: 24));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  void _commitPendingSubtask() {
    final title = _subtaskCtrl.text.trim();
    if (title.isEmpty) return;
    _subtasks.add(SubTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
    ));
    _subtaskCtrl.clear();
  }

  @override
  void setState(VoidCallback fn) {
    if (_submitting) return;
    super.setState(fn);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    _commitPendingSubtask();
    _submitting = true;
    try {
      final vm = context.read<TaskViewModel>();
      final reminderTime = _hasReminder
          ? (_reminderTime ?? _dueDate.subtract(const Duration(hours: 24)))
          : null;
      final type = TaskType.values.firstWhere(
        (e) => e.name.toLowerCase() == _type.toLowerCase(),
        orElse: () => TaskType.other,
      );
      final priority = TaskPriority.values.firstWhere(
        (e) => e.name.toLowerCase() == _priority.toLowerCase(),
        orElse: () => TaskPriority.medium,
      );
      final description =
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

      final bool ok;
      if (widget.isEditing) {
        final existing = widget.initialTask!;
        ok = await vm.updateTask(
          existing.copyWith(
            title: _titleCtrl.text.trim(),
            subject: _subjectCtrl.text.trim(),
            type: type,
            priority: priority,
            dueDate: _dueDate,
            description: description,
            subtasks: List<SubTask>.from(_subtasks),
            hasReminder: _hasReminder,
            reminderTime: reminderTime,
          ),
        );
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final notifId = DateTime.now().millisecondsSinceEpoch % 100000;
        ok = await vm.addTask(
          TaskModel(
            id: '',
            userId: uid,
            title: _titleCtrl.text.trim(),
            subject: _subjectCtrl.text.trim(),
            type: type,
            priority: priority,
            dueDate: _dueDate,
            status: TaskStatus.pending,
            description: description,
            createdAt: DateTime.now(),
            subtasks: _subtasks,
            hasReminder: _hasReminder,
            reminderTime: reminderTime,
            notificationId: notifId,
          ),
        );
      }
      if (!mounted) return;
      if (ok) Navigator.of(context, rootNavigator: false).pop();
    } finally {
      _submitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskViewModel>();
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: context.colors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    widget.isEditing ? 'Edit Task' : 'New Task',
                    style: context.text.h4,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BrainUpTextField(
                        label: 'Task Name',
                        controller: _titleCtrl,
                        validator: (v) =>
                            AppValidators.required(v, fieldName: 'Task name'),
                        prefixIcon: const Icon(Icons.task_alt_rounded),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      BrainUpTextField(
                        label: 'Subject',
                        controller: _subjectCtrl,
                        validator: (v) =>
                            AppValidators.required(v, fieldName: 'Subject'),
                        prefixIcon: const Icon(Icons.book_outlined),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),
                      Text('Type', style: context.text.label),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _types
                            .map((t) => BrainUpChip(
                                  label: t,
                                  isSelected: _type == t,
                                  onTap: () => setState(() => _type = t),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      Text('Priority', style: context.text.label),
                      const SizedBox(height: 8),
                      Row(
                        children: _priorities.map((p) {
                          final color = switch (p) {
                            'Critical' || 'High' => context.colors.error,
                            'Medium' => context.colors.warning,
                            _ => context.colors.success,
                          };
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: BrainUpChip(
                              label: p,
                              isSelected: _priority == p,
                              onTap: () => setState(() => _priority = p),
                              selectedColor: color,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Text('Due Date', style: context.text.label),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                            builder: (_, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context)
                                    .colorScheme
                                    .copyWith(primary: context.colors.accent),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _dueDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: context.colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: context.colors.surfaceBorder,
                                width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 18, color: context.colors.accent),
                              const SizedBox(width: 12),
                              Text(
                                AppDateUtils.formatDate(_dueDate),
                                style: context.text.body,
                              ),
                              const Spacer(),
                              Icon(Icons.chevron_right_rounded,
                                  color: context.colors.textMuted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      BrainUpTextField(
                        label: 'Description (optional)',
                        controller: _descCtrl,
                        maxLines: 3,
                        prefixIcon: const Icon(Icons.notes_rounded),
                      ),
                      const SizedBox(height: 18),
                      Text('Subtasks (optional)', style: context.text.label),
                      const SizedBox(height: 8),
                      ..._subtasks.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Icon(Icons.drag_handle_rounded,
                                  color: context.colors.textMuted, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(e.value.title,
                                      style: context.text.body)),
                              IconButton(
                                icon: Icon(Icons.close_rounded,
                                    size: 18,
                                    color: context.colors.textMuted),
                                onPressed: () =>
                                    setState(() => _subtasks.removeAt(e.key)),
                              ),
                            ]),
                          )),
                      Row(children: [
                        Expanded(
                            child: BrainUpTextField(
                          label: 'Add subtask...',
                          controller: _subtaskCtrl,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) =>
                              setState(_commitPendingSubtask),
                        )),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              setState(_commitPendingSubtask),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.colors.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      Row(children: [
                        Text('Reminder', style: context.text.label),
                        const Spacer(),
                        Switch(
                          value: _hasReminder,
                          activeThumbColor: context.colors.accent,
                          activeTrackColor: context.colors.accentSoft,
                          onChanged: (v) => setState(() {
                            _hasReminder = v;
                            if (!v) _reminderTime = null;
                          }),
                        ),
                      ]),
                      if (_hasReminder) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            '1 hour before',
                            '3 hours before',
                            '1 day before',
                          ].map((opt) {
                            final dur = opt == '1 hour before'
                                ? const Duration(hours: 1)
                                : opt == '3 hours before'
                                    ? const Duration(hours: 3)
                                    : const Duration(days: 1);
                            final time = _dueDate.subtract(dur);
                            return BrainUpChip(
                              label: opt,
                              isSelected: _reminderTime == time,
                              onTap: () =>
                                  setState(() => _reminderTime = time),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 28),
                      BrainUpButton(
                        label: widget.isEditing ? 'Save Changes' : 'Add Task',
                        onTap: vm.isSaving ? null : _submit,
                        isLoading: vm.isSaving,
                        icon: Icon(
                          widget.isEditing
                              ? Icons.save_rounded
                              : Icons.add_task_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
