import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/widgets/brainup_shimmer.dart';
import '../../../core/widgets/brainup_badge.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../tasks/models/task_model.dart';
import '../../timetable/models/lecture_model.dart';
import '../../timetable/viewmodels/timetable_viewmodel.dart';
import '../../cgpa/viewmodels/cgpa_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showNotificationsSheet(BuildContext context) {
    final vm = context.read<HomeViewModel>();
    final overdue = vm.tasks.where((t) => t.isOverdue).toList();
    final dueToday = vm.dueTodayTasks;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _NotificationsSheet(overdue: overdue, dueToday: dueToday),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final vm = context.watch<HomeViewModel>();
    final ttvm = context.watch<TimetableViewModel>();
    final cgpaVm = context.watch<CgpaViewModel>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surfaceCard,
        onRefresh: vm.refresh,
        child: CustomScrollView(
          slivers: [
            // ─── SliverAppBar ───
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              title: null,
              actions: [
                Stack(
                  children: [
                    IconButton(
                      onPressed: () => _showNotificationsSheet(context),
                      icon: const Icon(Icons.notifications_outlined,
                          color: AppColors.textPrimary),
                    ),
                    const Positioned(
                        top: 10, right: 10, child: BrainUpNotificationDot()),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${AppDateUtils.greetingByTime()}, ${user?.name.split(' ').first ?? 'Student'} 👋',
                            style: AppTextStyles.h3,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppDateUtils.formatDate(DateTime.now()),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Quick Stats ───
                    vm.isLoading
                        ? const ShimmerStatRow()
                        : _QuickStatsRow(vm: vm, cgpa: cgpaVm.cgpa)
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.05),

                    const SizedBox(height: AppSpacing.sectionSpacing),

                    // ─── Today's Schedule ───
                    _SectionHeader(
                      title: "Today's Schedule",
                      onSeeAll: () => context.go('/timetable'),
                    ).animate(delay: 50.ms).fadeIn(duration: 300.ms),
                    const SizedBox(height: 12),
                    // ─── In Progress Banner ───
                    if (!vm.isLoading && ttvm.currentLecture != null)
                      _InProgressCard(lecture: ttvm.currentLecture!)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: -0.05),
                    if (!vm.isLoading && ttvm.currentLecture != null)
                      const SizedBox(height: 10),
                    if (vm.isLoading)
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, __) => BrainUpShimmer(
                            child: Container(
                              width: 200,
                              height: 130,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (ttvm.todayLectures.isEmpty)
                      BrainUpCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No classes today 🎉',
                                style: AppTextStyles.bodySmall),
                          ),
                        ),
                      ).animate(delay: 100.ms).fadeIn()
                    else
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ttvm.todayLectures.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (ctx, i) => _LectureCard(
                            lecture: ttvm.todayLectures[i],
                          ).animate(delay: (i * 50).ms).fadeIn(duration: 300.ms).slideX(begin: 0.1),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.sectionSpacing),

                    // ─── Due Soon Tasks ───
                    _SectionHeader(
                      title: 'Due Soon',
                      onSeeAll: () => context.go('/tasks'),
                    ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
                    const SizedBox(height: 12),
                    if (vm.isLoading)
                      const ShimmerList(count: 3)
                    else if (vm.dueSoonTasks.isEmpty)
                      BrainUpCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No upcoming tasks! ✅',
                                style: AppTextStyles.bodySmall),
                          ),
                        ),
                      ).animate(delay: 150.ms).fadeIn()
                    else
                      ...vm.dueSoonTasks.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TaskCard(task: e.value)
                                .animate(delay: (e.key * 60).ms)
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: 0.05),
                          )),

                    const SizedBox(height: AppSpacing.sectionSpacing),

                    // ─── Quick Actions ───
                    Text('Quick Actions', style: AppTextStyles.h4)
                        .animate(delay: 150.ms)
                        .fadeIn(duration: 300.ms),
                    const SizedBox(height: 12),
                    _QuickActionsGrid()
                        .animate(delay: 180.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.05),

                    const SizedBox(height: AppSpacing.sectionSpacing),

                    // ─── Study Streak ───
                    _StudyStreakCard()
                        .animate(delay: 220.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.05),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final HomeViewModel vm;
  final double cgpa;
  const _QuickStatsRow({required this.vm, required this.cgpa});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatData(
        icon: Icons.assignment_outlined,
        value: vm.dueTodayTasks.length.toString(),
        label: 'Tasks Due',
        color: AppColors.warning,
      ),
      _StatData(
        icon: Icons.how_to_reg_outlined,
        value: '${vm.overallAttendance.toStringAsFixed(0)}%',
        label: 'Attendance',
        color: vm.overallAttendance >= 75
            ? AppColors.success
            : AppColors.error,
      ),
      _StatData(
        icon: Icons.school_outlined,
        value: cgpa.toStringAsFixed(2),
        label: 'CGPA',
        color: AppColors.info,
      ),
      _StatData(
        icon: Icons.timer_outlined,
        value: '${vm.studyHoursToday.toStringAsFixed(1)}h',
        label: 'Study Today',
        color: AppColors.accent,
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _StatCard(stat: stats[i]),
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatData({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatData stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return BrainUpCard(
      width: 130,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(stat.icon, size: 18, color: stat.color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stat.value,
                style: AppTextStyles.h4.copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                stat.label,
                style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LectureCard extends StatelessWidget {
  final LectureModel lecture;
  const _LectureCard({required this.lecture});

  @override
  Widget build(BuildContext context) {
    final subjectColor = AppColors.subjectColor(lecture.subject);
    return BrainUpCard(
      width: 200,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: subjectColor, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppDateUtils.timeFromString(lecture.startTime)} – ${AppDateUtils.timeFromString(lecture.endTime)}',
                style: AppTextStyles.label
                    .copyWith(color: subjectColor, fontSize: 12),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    lecture.subject,
                    style: AppTextStyles.h5,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('${lecture.room} · ${lecture.teacher}',
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  BrainUpTypeBadge(type: lecture.type),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final priorityColor = BrainUpPriorityBadge.colorFromString(task.priority.name);
    return BrainUpCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: priorityColor, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: BrainUpSubjectChip(subject: task.subject),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BrainUpPriorityBadge(
                  priority:
                      BrainUpPriorityBadge.fromString(task.priority.name)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.h4),
        const Spacer(),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
            child: Text('See all', style: AppTextStyles.accentText),
          ),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
          icon: Icons.add_task_rounded,
          label: 'Add Task',
          color: AppColors.accent,
          route: '/tasks'),
      _ActionData(
          icon: Icons.auto_awesome_rounded,
          label: 'AI Tools',
          color: AppColors.info,
          route: '/ai'),
      _ActionData(
          icon: Icons.how_to_reg_rounded,
          label: 'Attendance',
          color: AppColors.warning,
          route: '/attendance'),
      _ActionData(
          icon: Icons.timer_rounded,
          label: 'Study Timer',
          color: AppColors.success,
          route: '/study-timer'),
      _ActionData(
          icon: Icons.calculate_rounded,
          label: 'CGPA Calc',
          color: AppColors.error,
          route: '/cgpa'),
      _ActionData(
          icon: Icons.folder_rounded,
          label: 'Documents',
          color: AppColors.textSecondary,
          route: '/documents'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: actions.length,
      itemBuilder: (ctx, i) => _ActionTile(
        data: actions[i],
        onTap: () => ctx.go(actions[i].route),
      ).animate(delay: (i * 40).ms).fadeIn(duration: 250.ms).scale(
            begin: const Offset(0.9, 0.9),
            curve: Curves.easeOutBack,
          ),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  const _ActionData({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
}

class _ActionTile extends StatelessWidget {
  final _ActionData data;
  final VoidCallback onTap;

  const _ActionTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BrainUpCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, size: 26, color: data.color),
          ),
          const SizedBox(height: 8),
          Text(
            data.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StudyStreakCard extends StatelessWidget {
  // ── Motivational copy ──────────────────────────────────────────────────────
  static String _motivation(int days) => switch (days) {
        0 => 'Start your streak today! 🌱',
        1 => 'Day 1 done! Come back tomorrow 💪',
        2 => 'Two in a row! Keep the momentum 🌱',
        3 => 'Three days! A habit is forming 🔥',
        _ when days < 7 => '$days days strong! Don\'t break it 🔥',
        7 => 'One full week! That\'s incredible 🎯',
        _ when days < 14 => '$days days! You\'re on a roll 🚀',
        14 => 'Two-week warrior! Elite habits 🏆',
        _ when days < 21 => '$days days! Exceptional dedication 💎',
        21 => 'Three weeks! This is a lifestyle now 🧠',
        _ when days < 30 => '$days days! You\'re in rarified air 👑',
        _ => '$days day streak! Absolute legend 🌟',
      };

  // ── Current badge ──────────────────────────────────────────────────────────
  static ({String icon, String label, Color color}) _badge(int days) {
    if (days < 3) {
      return (icon: '🌱', label: 'Beginner', color: const Color(0xFF4CAF50));
    }
    if (days < 7) {
      return (icon: '🔥', label: 'Streaking', color: const Color(0xFFFF7043));
    }
    if (days < 14) {
      return (icon: '🚀', label: 'On Fire', color: const Color(0xFF7C4DFF));
    }
    if (days < 21) {
      return (icon: '💎', label: 'Diamond', color: const Color(0xFF00BCD4));
    }
    if (days < 30) {
      return (icon: '👑', label: 'Legend', color: const Color(0xFFFFAA00));
    }
    return (icon: '🌟', label: 'Transcendent', color: const Color(0xFFFFD700));
  }

  // ── Next milestone ─────────────────────────────────────────────────────────
  static ({String icon, String label, Color color, int target}) _next(
      int days) {
    const milestones = [
      (icon: '🌱', label: 'Sprouting', color: Color(0xFF4CAF50), target: 3),
      (icon: '🔥', label: 'On Fire', color: Color(0xFFFF7043), target: 7),
      (icon: '🚀', label: 'Rocket', color: Color(0xFF7C4DFF), target: 14),
      (icon: '💎', label: 'Diamond', color: Color(0xFF00BCD4), target: 21),
      (icon: '👑', label: 'Legend', color: Color(0xFFFFAA00), target: 30),
    ];
    for (final m in milestones) {
      if (days < m.target) return m;
    }
    return (
      icon: '🌟',
      label: 'Transcendent',
      color: const Color(0xFFFFD700),
      target: 30
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeVm = context.watch<HomeViewModel>();
    final streakDays = homeVm.studyStreakDays;
    final weekDays = homeVm.weekStudiedDays; // List<bool> Mon–Sun
    final todayIdx = DateTime.now().weekday - 1; // 0=Mon … 6=Sun

    final badge = _badge(streakDays);
    final next = _next(streakDays);
    final reached30 = streakDays >= 30;
    final progress =
        reached30 ? 1.0 : (streakDays / next.target).clamp(0.0, 1.0);
    final daysLeft = next.target - streakDays;

    return BrainUpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icon + count + badge ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                streakDays > 0 ? '🔥' : '💤',
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 10),
              Text(
                streakDays == 0 ? 'No streak yet' : '$streakDays Day Streak',
                style: AppTextStyles.h4,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badge.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badge.color.withOpacity(0.4)),
                ),
                child: Text(
                  '${badge.icon} ${badge.label}',
                  style: AppTextStyles.caption.copyWith(
                    color: badge.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── Motivational subtitle ─────────────────────────────────────────
          Text(
            _motivation(streakDays),
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),

          // ── Weekly dots (actual studied days) ─────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isStudied = i < weekDays.length && weekDays[i];
              final isToday = i == todayIdx;
              const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              return Column(
                children: [
                  Text(
                    labels[i],
                    style: AppTextStyles.labelSmall.copyWith(
                      color:
                          isToday ? AppColors.accent : AppColors.textMuted,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 280 + i * 45),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isStudied
                          ? const LinearGradient(
                              colors: [Color(0xFF00C2FF), Color(0xFF0055FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isStudied ? null : AppColors.surfaceElevated,
                      border: isToday
                          ? Border.all(
                              color: isStudied
                                  ? Colors.white.withOpacity(0.45)
                                  : AppColors.accent,
                              width: 2,
                            )
                          : null,
                      boxShadow: isStudied
                          ? [
                              BoxShadow(
                                color: AppColors.accent.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isStudied
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : isToday
                              ? Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                    ),
                  ),
                ],
              );
            }),
          ),

          // ── Milestone progress bar ────────────────────────────────────────
          const SizedBox(height: 16),
          if (!reached30) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${next.icon} Next: ${next.label}',
                  style: AppTextStyles.caption.copyWith(
                    color: next.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  daysLeft == 1 ? '1 day to go!' : '$daysLeft days to go',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => LinearProgressIndicator(
                  value: val,
                  minHeight: 7,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(next.color),
                ),
              ),
            ),
          ] else
            Center(
              child: Text(
                '🌟 Maximum milestone reached! You\'re a legend.',
                style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFFFFD700),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Notifications Sheet ──────────────────────────────────────────────────────

class _NotificationsSheet extends StatelessWidget {
  final List<TaskModel> overdue;
  final List<TaskModel> dueToday;

  const _NotificationsSheet({
    required this.overdue,
    required this.dueToday,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = overdue.isEmpty && dueToday.isEmpty;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  Text('Notifications', style: AppTextStyles.h4),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceBorder),
            Expanded(
              child: isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              size: 52, color: AppColors.success),
                          const SizedBox(height: 12),
                          Text(
                            "You're all caught up! 🎉",
                            style: AppTextStyles.h5
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        if (dueToday.isNotEmpty) ...[
                          _SheetSectionHeader(
                            label: 'Due Today',
                            count: dueToday.length,
                            color: AppColors.accent,
                          ),
                          const SizedBox(height: 8),
                          ...dueToday.map((t) => _NotifTaskTile(
                                task: t,
                                highlightColor: AppColors.accent,
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (overdue.isNotEmpty) ...[
                          _SheetSectionHeader(
                            label: 'Overdue',
                            count: overdue.length,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 8),
                          ...overdue.map((t) => _NotifTaskTile(
                                task: t,
                                highlightColor: AppColors.error,
                              )),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SheetSectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.label.copyWith(color: color, letterSpacing: 1),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _NotifTaskTile extends StatelessWidget {
  final TaskModel task;
  final Color highlightColor;

  const _NotifTaskTile({required this.task, required this.highlightColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrainUpCard(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(
                left: BorderSide(color: highlightColor, width: 3)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.subject,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: highlightColor,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        task.title,
                        style: AppTextStyles.h5,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppDateUtils.relativeDate(task.dueDate),
                        style: AppTextStyles.caption.copyWith(
                          color: highlightColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                BrainUpPriorityBadge(
                  priority:
                      BrainUpPriorityBadge.fromString(task.priority.name),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── In Progress Card ─────────────────────────────────────────────────────────

class _InProgressCard extends StatelessWidget {
  final LectureModel lecture;
  const _InProgressCard({required this.lecture});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'In Progress: ${lecture.subject}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(lecture.room, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
