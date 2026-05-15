import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/widgets/brainup_shimmer.dart';
import '../../../core/widgets/brainup_chip.dart';
import '../../../core/widgets/brainup_badge.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../../../core/widgets/brainup_empty_state.dart';
import '../../../core/widgets/brainup_error_state.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../models/task_model.dart';
import '../viewmodels/task_viewmodel.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskViewModel>();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ─── App Bar ───
            _TasksAppBar(vm: vm),
            // ─── Stats Banner ───
            _TaskStatsBanner(vm: vm),
            // ─── Filter Chips ───
            _FilterRow(vm: vm),
            // ─── List ───
            Expanded(child: _TaskList(vm: vm, onAddTask: () => _showAddTaskSheet(context, vm),)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskSheet(context, vm),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ).animate().scale(
            delay: 300.ms,
            curve: Curves.elasticOut,
            duration: 600.ms,
          ),
    );
  }

  void _showAddTaskSheet(BuildContext context, TaskViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const AddTaskSheet(),
      ),
    );
  }
}

class _TasksAppBar extends StatelessWidget {
  final TaskViewModel vm;
  const _TasksAppBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Text('Tasks', style: AppTextStyles.h3),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${vm.filteredTasks.length}',
              style: AppTextStyles.label.copyWith(color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.sort_rounded, color: AppColors.textSecondary),
            onPressed: () => _showSortSheet(context, vm),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final TaskViewModel vm;
  const _FilterRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'Today', 'This Week', 'Overdue', 'Completed'];
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...filters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: BrainUpChip(
                  label: f,
                  isSelected: vm.filter == f,
                  onTap: () => vm.setFilter(f),
                ),
              )),
          if (vm.subjects.isNotEmpty)
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: AppColors.surfaceBorder,
            ),
          ...vm.subjects.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: BrainUpChip(
                  label: s,
                  isSelected: vm.subjectFilter == s,
                  onTap: () => vm.setSubjectFilter(vm.subjectFilter == s ? null : s),
                  selectedColor: AppColors.subjectColor(s),
                ),
              )),
          if (vm.filter != 'All' && vm.subjectFilter != null)
            TextButton(
              onPressed: vm.clearAllFilters,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Clear filters',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.accent),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final TaskViewModel vm;
  final VoidCallback onAddTask;
  const _TaskList({required this.vm,required this.onAddTask});

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        child: ShimmerList(),
      );
    }
    if (vm.error != null) {
      return BrainUpErrorState(
        message: vm.error,
        onRetry: vm.loadTasks,
      );
    }
    if (vm.filteredTasks.isEmpty) {
      return BrainUpEmptyState(
        variant: EmptyStateVariant.tasks,
        actionLabel: 'Add Task',
        onAction: onAddTask,
      );
    }

    final groups = vm.sortedGroupKeys;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: groups.length,
      itemBuilder: (ctx, gi) {
        final group = groups[gi];
        final tasks = vm.groupedTasks[group]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Text(group,
                      style: AppTextStyles.label.copyWith(
                        color: _groupColor(group),
                        letterSpacing: 1,
                      )),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _groupColor(group).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: AppTextStyles.caption
                          .copyWith(color: _groupColor(group)),
                    ),
                  ),
                ],
              ),
            ),
            ...tasks.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TaskListItem(
                    task: e.value,
                    vm: vm,
                  )
                      .animate(delay: (e.key * 40).ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.05),
                )),
          ],
        );
      },
    );
  }

  Color _groupColor(String group) => switch (group) {
        'OVERDUE' => AppColors.error,
        'TODAY' => AppColors.accent,
        'TOMORROW' => AppColors.info,
        'COMPLETED' => AppColors.success,
        _ => AppColors.textSecondary,
      };
}

class _TaskListItem extends StatelessWidget {
  final TaskModel task;
  final TaskViewModel vm;

  const _TaskListItem({required this.task, required this.vm});

  @override
  Widget build(BuildContext context) {
    final priorityColor = BrainUpPriorityBadge.colorFromString(task.priority.name);

    return Slidable(
      key: Key(task.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.mediumImpact();
              vm.completeTask(task.id);
            },
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            icon: Icons.check_circle_rounded,
            label: 'Done',
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
          ),
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              _confirmDelete(context, vm, task);
            },
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Delete',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ],
      ),
      child: BrainUpCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Priority left border
                Container(
                  width: 4,
                  color: priorityColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: BrainUpSubjectChip(
                                    subject: task.subject, small: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: BrainUpTypeBadge(type: task.type.name),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppDateUtils.relativeDate(task.dueDate),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: task.isOverdue
                                      ? AppColors.error
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          task.title,
                          style: AppTextStyles.h5.copyWith(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.description != null &&
                            task.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Checkbox
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(
                    value: task.isCompleted,
                    onChanged: (_) {
                      HapticFeedback.mediumImpact();
                      if (!task.isCompleted) vm.completeTask(task.id);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ADD TASK SHEET ───────────────────────────────────────────────────────────

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _subtaskCtrl = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  String _type = 'Assignment';
  String _priority = 'Medium';
  final List<SubTask> _subtasks = [];
  bool _hasReminder = false;
  DateTime? _reminderTime;

  final _types = ['Assignment', 'Quiz', 'Project', 'Homework', 'Exam', 'Lab', 'Presentation', 'Other'];
  final _priorities = ['Low', 'Medium', 'High', 'Critical'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<TaskViewModel>();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final notifId = DateTime.now().millisecondsSinceEpoch % 100000;
    final task = TaskModel(
      id: '',
      userId: uid,
      title: _titleCtrl.text.trim(),
      subject: _subjectCtrl.text.trim(),
      type: TaskType.values.firstWhere(
        (e) => e.name.toLowerCase() == _type.toLowerCase(),
        orElse: () => TaskType.other,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name.toLowerCase() == _priority.toLowerCase(),
        orElse: () => TaskPriority.medium,
      ),
      dueDate: _dueDate,
      status: TaskStatus.pending,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      createdAt: DateTime.now(),
      subtasks: _subtasks,
      hasReminder: _hasReminder,
      reminderTime: _reminderTime,
      notificationId: notifId,
    );
    final ok = await vm.addTask(task);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskViewModel>();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('New Task', style: AppTextStyles.h4),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
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
                        validator: (v) => AppValidators.required(v, fieldName: 'Task name'),
                        prefixIcon: const Icon(Icons.task_alt_rounded),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      BrainUpTextField(
                        label: 'Subject',
                        controller: _subjectCtrl,
                        validator: (v) => AppValidators.required(v, fieldName: 'Subject'),
                        prefixIcon: const Icon(Icons.book_outlined),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),
                      Text('Type', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _types.map((t) => BrainUpChip(
                          label: t,
                          isSelected: _type == t,
                          onTap: () => setState(() => _type = t),
                        )).toList(),
                      ),
                      const SizedBox(height: 18),
                      Text('Priority', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      Row(
                        children: _priorities.map((p) {
                          final color = switch (p) {
                            'High' => AppColors.error,
                            'Medium' => AppColors.warning,
                            _ => AppColors.success,
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
                      Text('Due Date', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (_, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context)
                                    .colorScheme
                                    .copyWith(primary: AppColors.accent),
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
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.surfaceBorder, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 18, color: AppColors.accent),
                              const SizedBox(width: 12),
                              Text(
                                AppDateUtils.formatDate(_dueDate),
                                style: AppTextStyles.body,
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.textMuted),
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
                      // ─── Subtasks ───
                      Text('Subtasks (optional)', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      ..._subtasks.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          const Icon(Icons.drag_handle_rounded,
                              color: AppColors.textMuted, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.value.title,
                              style: AppTextStyles.body)),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: AppColors.textMuted),
                            onPressed: () =>
                                setState(() => _subtasks.removeAt(e.key)),
                          ),
                        ]),
                      )),
                      Row(children: [
                        Expanded(child: BrainUpTextField(
                          label: 'Add subtask...',
                          controller: _subtaskCtrl,
                          textInputAction: TextInputAction.done,
                        )),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            if (_subtaskCtrl.text.trim().isNotEmpty) {
                              setState(() {
                                _subtasks.add(SubTask(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  title: _subtaskCtrl.text.trim(),
                                ));
                                _subtaskCtrl.clear();
                              });
                            }
                          },
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      // ─── Reminder ───
                      Row(children: [
                        Text('Reminder', style: AppTextStyles.label),
                        const Spacer(),
                        Switch(
                          value: _hasReminder,
                          activeThumbColor: AppColors.accent,
                          activeTrackColor: AppColors.accentSoft,
                          onChanged: (v) => setState(() {
                            _hasReminder = v;
                            if (!v) _reminderTime = null;
                          }),
                        ),
                      ]),
                      if (_hasReminder) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8,
                          children: [
                            '1 hour before',
                            '3 hours before',
                            '1 day before'
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
                        label: 'Add Task',
                        onTap: vm.isSaving ? null : _submit,
                        isLoading: vm.isSaving,
                        icon: const Icon(Icons.add_task_rounded,
                            color: Colors.white, size: 18),
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

// ─── Stats Banner ─────────────────────────────────────────────────────────────

class _TaskStatsBanner extends StatelessWidget {
  final TaskViewModel vm;
  const _TaskStatsBanner({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.pendingCount == 0 && vm.overdueCount == 0 && vm.dueTodayCount == 0) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          if (vm.pendingCount > 0)
            _StatChip(
              label: '${vm.pendingCount} Pending',
              color: AppColors.accent,
              icon: Icons.pending_actions_rounded,
              onTap: () => vm.setFilter('All'),
            ),
          if (vm.overdueCount > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              label: '${vm.overdueCount} Overdue',
              color: AppColors.error,
              icon: Icons.warning_amber_rounded,
              onTap: () => vm.setFilter('Overdue'),
            ),
          ],
          if (vm.dueTodayCount > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              label: '${vm.dueTodayCount} Due Today',
              color: AppColors.warning,
              icon: Icons.today_rounded,
              onTap: () => vm.setFilter('Today'),
            ),
          ],
          if (vm.completedThisWeek > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              label: '${vm.completedThisWeek} Done',
              color: AppColors.success,
              icon: Icons.check_circle_rounded,
              onTap: () => vm.setFilter('Completed'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _StatChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── Sort Sheet ───────────────────────────────────────────────────────────────

void _showSortSheet(BuildContext context, TaskViewModel vm) {
  const options = [
    'Due Date (Earliest)',
    'Due Date (Latest)',
    'Priority (High→Low)',
    'Subject A→Z',
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Sort By', style: AppTextStyles.h4),
          const SizedBox(height: 12),
          ...options.map((opt) {
            final isSelected = vm.sortOrder == opt;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
                size: 22,
              ),
              title: Text(
                opt,
                style: AppTextStyles.body.copyWith(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              onTap: () {
                vm.setSortOrder(opt);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    ),
  );
}

// ─── Delete Confirmation ──────────────────────────────────────────────────────

void _confirmDelete(BuildContext context, TaskViewModel vm, TaskModel task) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.delete_outline_rounded,
              color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text('Delete Task?', style: AppTextStyles.h4),
          const SizedBox(height: 8),
          Text(task.title,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: BrainUpButton.secondary(
                label: 'Cancel',
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  vm.deleteTask(task.id);
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Center(
                    child: Text('Delete',
                        style: AppTextStyles.button
                            .copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
