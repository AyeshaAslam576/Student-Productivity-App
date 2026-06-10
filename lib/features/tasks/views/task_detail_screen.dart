import 'package:flutter/material.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/brainup_badge.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/widgets/brainup_chip.dart';
import '../models/task_model.dart';
import '../viewmodels/task_viewmodel.dart';
import 'add_task_sheet.dart';

class TaskDetailScreen extends StatelessWidget {
  final TaskModel task;
  final TaskViewModel vm;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.vm,
  });

  TaskModel _resolveTask(TaskViewModel vm) {
    for (final t in vm.allTasks) {
      if (t.id == task.id) return t;
    }
    return task;
  }

  Color _priorityColor(TaskPriority priority, dynamic colors) {
    return switch (priority) {
      TaskPriority.critical || TaskPriority.high => colors.error,
      TaskPriority.medium => colors.warning,
      TaskPriority.low => colors.success,
    };
  }

  BadgePriority _badgePriority(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.critical || TaskPriority.high => BadgePriority.high,
      TaskPriority.medium => BadgePriority.medium,
      TaskPriority.low => BadgePriority.low,
    };
  }

  Future<void> _delete(BuildContext context, TaskModel current) async {
    final ok = await vm.deleteTask(current.id);
    if (!context.mounted) return;
    if (ok) brainupPop(context, fallback: '/tasks');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final colors = context.colors;
        final text = context.text;
        final current = _resolveTask(vm);

        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: brainUpBackButton(context,
                fallback: '/tasks', iconColor: colors.textPrimary),
            title: Text(
              current.title,
              style: text.h5,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: colors.accent),
                tooltip: 'Edit task',
                onPressed: () =>
                    showAddTaskSheet(context, vm, initialTask: current),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _PriorityBanner(
                task: current,
                priorityColor: _priorityColor(current.priority, colors),
                badgePriority: _badgePriority(current.priority),
              ),
              if (current.description != null &&
                  current.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Description', style: text.label),
                const SizedBox(height: 8),
                BrainUpCard(
                  child: Text(
                    current.description!,
                    style: text.body.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Subtasks', style: text.label),
                  if (current.subtasks.isNotEmpty) ...[
                    const Spacer(),
                    Text(
                      '${current.subtaskCompletedCount}/${current.subtasks.length}',
                      style: text.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (current.subtasks.isEmpty)
                BrainUpCard(
                  child: Text(
                    'No subtasks yet. Tap the edit icon above to add a checklist.',
                    style: text.bodySmall
                        .copyWith(color: colors.textSecondary),
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: current.subtaskProgress,
                    minHeight: 6,
                    backgroundColor: colors.surfaceElevated,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                BrainUpCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: current.subtasks.map((sub) {
                      return CheckboxListTile(
                        value: sub.isCompleted,
                        activeColor: colors.accent,
                        checkColor: Colors.white,
                        title: Text(
                          sub.title,
                          style: text.body.copyWith(
                            decoration: sub.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: sub.isCompleted
                                ? colors.textMuted
                                : colors.textPrimary,
                          ),
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          vm.toggleSubtask(current.id, sub.id, value);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
              if (current.hasReminder && current.reminderTime != null) ...[
                const SizedBox(height: 20),
                Text('Reminder', style: text.label),
                const SizedBox(height: 8),
                BrainUpCard(
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          color: colors.accent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scheduled reminder', style: text.body),
                            const SizedBox(height: 2),
                            Text(
                              AppDateUtils.formatDateTime(
                                  current.reminderTime!),
                              style: text.caption
                                  .copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _DeleteTaskButton(
                onTap: () => _delete(context, current),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PriorityBanner extends StatelessWidget {
  final TaskModel task;
  final Color priorityColor;
  final BadgePriority badgePriority;

  const _PriorityBanner({
    required this.task,
    required this.priorityColor,
    required this.badgePriority,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return BrainUpCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: priorityColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (task.priority == TaskPriority.critical)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: colors.error.withValues(alpha: 0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                'CRITICAL',
                                style: text.labelSmall
                                    .copyWith(color: colors.error),
                              ),
                            )
                          else
                            BrainUpPriorityBadge(priority: badgePriority),
                          BrainUpTypeBadge(type: task.type.name),
                          BrainUpChip(
                            label: AppDateUtils.relativeDate(task.dueDate),
                            isSelected: true,
                            selectedColor: task.isOverdue
                                ? colors.error
                                : colors.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(task.subject, style: text.caption),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteTaskButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteTaskButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: colors.error,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Delete Task',
                  style: text.button.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
