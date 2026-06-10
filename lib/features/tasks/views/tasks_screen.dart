import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/widgets/brainup_shimmer.dart';
import '../../../core/widgets/brainup_chip.dart';
import '../../../core/widgets/brainup_badge.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_empty_state.dart';
import '../../../core/widgets/brainup_error_state.dart';
import '../../../core/utils/date_utils.dart';
import '../models/task_model.dart';
import '../viewmodels/task_viewmodel.dart';
import 'add_task_sheet.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskViewModel>();
    return Scaffold(
      backgroundColor: context.colors.surface,
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
        backgroundColor: context.colors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ).animate().scale(
            delay: 300.ms,
            curve: Curves.elasticOut,
            duration: 600.ms,
          ),
    );
  }

  void _showAddTaskSheet(BuildContext context, TaskViewModel vm) {
    showAddTaskSheet(context, vm);
  }
}

class _TasksAppBar extends StatelessWidget {
  final TaskViewModel vm;
  const _TasksAppBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.surfaceBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Text('Tasks', style: context.text.h3),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${vm.filteredTasks.length}',
              style: context.text.label.copyWith(color: context.colors.accent),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.sort_rounded, color: context.colors.textSecondary),
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
              color: context.colors.surfaceBorder,
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
                style: context.text.bodySmall
                    .copyWith(color: context.colors.accent),
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
                      style: context.text.label.copyWith(
                        color: _groupColor(ctx, group),
                        letterSpacing: 1,
                      )),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _groupColor(ctx, group).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: context.text.caption
                          .copyWith(color: _groupColor(ctx, group)),
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

  Color _groupColor(BuildContext context, String group) => switch (group) {
        'OVERDUE' => context.colors.error,
        'TODAY' => context.colors.accent,
        'TOMORROW' => context.colors.info,
        'COMPLETED' => context.colors.success,
        _ => context.colors.textSecondary,
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
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.30,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.mediumImpact();
              vm.completeTask(task.id);
            },
            backgroundColor: context.colors.success,
            foregroundColor: Colors.white,
            icon: Icons.check_circle_rounded,
            label: 'Done',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.30,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              _confirmDelete(context, vm, task);
            },
            backgroundColor: context.colors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => context.push('/tasks/${task.id}'),
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
                                style: context.text.caption.copyWith(
                                  color: task.isOverdue
                                      ? context.colors.error
                                      : context.colors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          task.title,
                          style: context.text.h5.copyWith(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? context.colors.textMuted
                                : context.colors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.description != null &&
                            task.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            style: context.text.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (task.subtasks.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${task.subtaskCompletedCount}/${task.subtasks.length} subtasks',
                            style: context.text.caption.copyWith(
                              color: context.colors.accent,
                            ),
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
                      vm.toggleTaskCompletion(task.id);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
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
              color: context.colors.accent,
              icon: Icons.pending_actions_rounded,
              onTap: () => vm.setFilter('All'),
            ),
          if (vm.overdueCount > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              label: '${vm.overdueCount} Overdue',
              color: context.colors.error,
              icon: Icons.warning_amber_rounded,
              onTap: () => vm.setFilter('Overdue'),
            ),
          ],
          if (vm.dueTodayCount > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              label: '${vm.dueTodayCount} Due Today',
              color: context.colors.warning,
              icon: Icons.today_rounded,
              onTap: () => vm.setFilter('Today'),
            ),
          ],
          if (vm.completedThisWeek > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              label: '${vm.completedThisWeek} Done',
              color: context.colors.success,
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
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                color: context.colors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Sort By', style: context.text.h4),
          const SizedBox(height: 12),
          ...options.map((opt) {
            final isSelected = vm.sortOrder == opt;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? context.colors.accent : context.colors.textMuted,
                size: 22,
              ),
              title: Text(
                opt,
                style: context.text.body.copyWith(
                  color: isSelected
                      ? context.colors.accent
                      : context.colors.textPrimary,
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
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Icon(Icons.delete_outline_rounded,
              color: context.colors.error, size: 40),
          const SizedBox(height: 12),
          Text('Delete Task?', style: context.text.h4),
          const SizedBox(height: 8),
          Text(task.title,
              style:
                  context.text.body.copyWith(color: context.colors.textSecondary),
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
                    color: context.colors.error,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Center(
                    child: Text('Delete',
                        style: context.text.button
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
