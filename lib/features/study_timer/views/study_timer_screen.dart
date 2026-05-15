import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/utils/date_utils.dart';
import '../../timetable/viewmodels/timetable_viewmodel.dart';
import '../models/timer_phase.dart';
import '../viewmodels/timer_viewmodel.dart';

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> {
  bool _subjectsSeeded = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TimerViewModel>();
    if (!_subjectsSeeded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final lectures = context.read<TimetableViewModel>().lectures;
        final subjects =
            lectures.map((lecture) => lecture.subject).toSet().toList();
        context.read<TimerViewModel>().loadSubjectsFromTimetable(subjects);
      });
      _subjectsSeeded = true;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            left: MediaQuery.of(context).size.width / 2 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _phaseColor(vm.phase).withOpacity(0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.textPrimary),
                      ),
                      Text('Study Timer', style: AppTextStyles.h3),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _FocusModeOverlay(vm: vm),
                            ),
                          );
                        },
                        icon: const Icon(Icons.fullscreen_rounded,
                            color: AppColors.textSecondary),
                      ),
                      IconButton(
                        onPressed: () => _showSettings(context, vm),
                        icon: const Icon(Icons.tune_rounded,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Subject selector
                        _SubjectSelector(vm: vm),
                        const SizedBox(height: 12),
                        _AmbientSoundRow(vm: vm),
                        const SizedBox(height: 40),
                        // Circular timer
                        _CircularTimer(vm: vm),
                        const SizedBox(height: 32),
                        // Session dots
                        _SessionDots(vm: vm),
                        const SizedBox(height: 32),
                        // Controls
                        _Controls(vm: vm),
                        const SizedBox(height: 32),
                        if (vm.isLoadingCoach)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (vm.aiCoachMessage != null)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: BrainUpCard(
                              key: ValueKey(vm.aiCoachMessage),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent.withOpacity(0.06),
                                  AppColors.surfaceCard,
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      gradient: AppColors.accentGradient,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      vm.aiCoachMessage!,
                                      style: AppTextStyles.body
                                          .copyWith(height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .slideY(begin: 0.1),
                          ),
                        const SizedBox(height: 20),
                        _StudyStatsSection(vm: vm),
                        const SizedBox(height: 24),
                        // Session history
                        if (vm.sessionHistory.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Recent Sessions',
                                style: AppTextStyles.h4),
                          ),
                          const SizedBox(height: 12),
                          ...vm.sessionHistory.take(5).map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: BrainUpCard(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.success
                                              .withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_rounded,
                                            size: 14, color: AppColors.success),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(s.subject,
                                                style: AppTextStyles.body),
                                            Text(
                                                AppDateUtils.formatDateTime(
                                                    s.completedAt),
                                                style: AppTextStyles.caption),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        AppDateUtils.formatDuration(Duration(
                                            seconds: s.durationSeconds)),
                                        style: AppTextStyles.label
                                            .copyWith(color: AppColors.accent),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _phaseColor(TimerPhase phase) => switch (phase) {
        TimerPhase.focus => AppColors.accent,
        TimerPhase.shortBreak => AppColors.success,
        TimerPhase.longBreak => AppColors.info,
      };

  void _showSettings(BuildContext context, TimerViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom,
        ),
        child: _SettingsSheet(vm: vm),
      ),
    );
  }
}

class _SubjectSelector extends StatelessWidget {
  final TimerViewModel vm;
  const _SubjectSelector({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: vm.availableSubjects.map((s) {
          final selected = vm.selectedSubject == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => vm.setSubject(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accentSoft
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        selected ? AppColors.accent : AppColors.surfaceBorder,
                    width: selected ? 1 : 0.5,
                  ),
                ),
                child: Text(
                  s,
                  style: AppTextStyles.labelSmall.copyWith(
                    color:
                        selected ? AppColors.accent : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AmbientSoundRow extends StatelessWidget {
  final TimerViewModel vm;
  const _AmbientSoundRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: vm.ambientSounds.length,
        itemBuilder: (context, index) {
          final sound = vm.ambientSounds[index];
          final selected = vm.selectedSound == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => vm.selectSound(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accentSoft
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color:
                        selected ? AppColors.accent : AppColors.surfaceBorder,
                    width: selected ? 1 : 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(sound['icon'] ?? ''),
                    const SizedBox(width: 6),
                    Text(
                      sound['label'] ?? '',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: selected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StudyStatsSection extends StatelessWidget {
  final TimerViewModel vm;
  const _StudyStatsSection({required this.vm});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    if (vm.isLoadingStats && vm.weeklyMinutes.isEmpty) {
      return BrainUpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Week', style: AppTextStyles.h4),
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
            Text(
              'Loading your weekly study insights...',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }

    if (vm.statsError != null && vm.weeklyMinutes.isEmpty) {
      return BrainUpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Week', style: AppTextStyles.h4),
            const SizedBox(height: 12),
            Text(vm.statsError!, style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: vm.loadStats,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
      );
    }

    final weekly =
        List<int>.generate(7, (index) => vm.weeklyMinutes['${index + 1}'] ?? 0);
    final maxMinutes = weekly.reduce((a, b) => a > b ? a : b);
    final maxY = (maxMinutes < 60 ? 60 : maxMinutes).toDouble();
    final totalMin = vm.totalWeeklyMinutes;
    final totalHours = totalMin ~/ 60;
    final remainingMin = totalMin % 60;
    final todayIdx = DateTime.now().weekday - 1;

    return BrainUpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week', style: AppTextStyles.h4),
          if (vm.streakDays > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Text('🔥'),
                  const SizedBox(width: 8),
                  Text(
                    '${vm.streakDays} day streak',
                    style:
                        AppTextStyles.label.copyWith(color: AppColors.warning),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: 60,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.surfaceBorder.withOpacity(0.3),
                      strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value ~/ 60)}h',
                          style: AppTextStyles.caption,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx > 6) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_days[idx], style: AppTextStyles.caption),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(7, (index) {
                  final isToday = index == todayIdx;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: weekly[index].toDouble(),
                        width: 16,
                        borderRadius: BorderRadius.circular(8),
                        gradient: isToday
                            ? const LinearGradient(
                                colors: [AppColors.warning, AppColors.accent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )
                            : AppColors.accentGradient,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Total this week: ${totalHours} hours ${remainingMin} min',
            style: AppTextStyles.body.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Most studied subject: ${vm.mostStudiedSubjectThisWeek}',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CircularTimer extends StatelessWidget {
  final TimerViewModel vm;
  const _CircularTimer({required this.vm});

  Color get _phaseColor => switch (vm.phase) {
        TimerPhase.focus => AppColors.accent,
        TimerPhase.shortBreak => AppColors.success,
        TimerPhase.longBreak => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      child: CircularPercentIndicator(
        radius: 130,
        lineWidth: 10,
        percent: vm.progress.clamp(0.0, 1.0),
        animation: false,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              vm.timeDisplay,
              style: AppTextStyles.monospace.copyWith(fontSize: 42),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _phaseColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                vm.phaseLabel,
                style: AppTextStyles.label.copyWith(
                  color: _phaseColor,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        progressColor: _phaseColor,
        backgroundColor: AppColors.surfaceBorder,
        circularStrokeCap: CircularStrokeCap.round,
      ),
    );
  }
}

class _SessionDots extends StatelessWidget {
  final TimerViewModel vm;
  const _SessionDots({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final done = i < vm.sessionsCompleted % 4;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: done ? 12 : 10,
          height: done ? 12 : 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.accent : AppColors.surfaceElevated,
            border: Border.all(
              color: done ? AppColors.accent : AppColors.surfaceBorder,
              width: 1,
            ),
          ),
        );
      }),
    );
  }
}

class _Controls extends StatelessWidget {
  final TimerViewModel vm;
  const _Controls({required this.vm});

  Color get _phaseColor => switch (vm.phase) {
        TimerPhase.focus => AppColors.accent,
        TimerPhase.shortBreak => AppColors.success,
        TimerPhase.longBreak => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    final isBreak = vm.phase != TimerPhase.focus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Break phase: prominent "Study Now" action ────────────────────
        if (isBreak) ...[
          GestureDetector(
            onTap: vm.skip,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_phaseColor, _phaseColor.withOpacity(0.75)],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: _phaseColor.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Skip Break — Study Now',
                    style: AppTextStyles.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 16),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .scale(
                begin: const Offset(0.92, 0.92),
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 18),
        ],

        // ── Play / Pause · Skip · Reset row ──────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              icon: Icons.skip_next_rounded,
              onTap: vm.skip,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: vm.isRunning ? vm.pause : vm.start,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isBreak ? 60 : 72,
                height: isBreak ? 60 : 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isBreak
                      ? LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.08)
                          ],
                        )
                      : AppColors.accentGradient,
                  border: isBreak
                      ? Border.all(color: AppColors.surfaceBorder)
                      : null,
                ),
                child: Icon(
                  vm.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isBreak ? AppColors.textSecondary : Colors.white,
                  size: isBreak ? 28 : 36,
                ),
              ),
            ).animate(key: ValueKey(vm.isRunning)).scale(
                  begin: const Offset(0.9, 0.9),
                  duration: 200.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(width: 16),
            _ControlButton(
              icon: Icons.refresh_rounded,
              onTap: vm.reset,
              size: 48,
              color: AppColors.textSecondary,
            ),
          ],
        ),

        // ── Break caption under controls ──────────────────────────────────
        if (isBreak) ...[
          const SizedBox(height: 10),
          Text(
            'or keep resting — timer is running',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;
  const _ControlButton(
      {required this.icon,
      required this.onTap,
      required this.size,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceElevated,
          border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  final TimerViewModel vm;
  const _SettingsSheet({required this.vm});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late int _focus;
  late int _short;
  late int _long;

  @override
  void initState() {
    super.initState();
    _focus = widget.vm.focusDuration ~/ 60;
    _short = widget.vm.shortBreakDuration ~/ 60;
    _long = widget.vm.longBreakDuration ~/ 60;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Timer Settings', style: AppTextStyles.h4),
          const SizedBox(height: 20),
          _DurationSetting(
            label: 'Focus Duration',
            value: _focus,
            min: 5,
            max: 60,
            suffix: 'min',
            onChanged: (v) => setState(() => _focus = v),
          ),
          const SizedBox(height: 14),
          _DurationSetting(
            label: 'Short Break',
            value: _short,
            min: 1,
            max: 30,
            suffix: 'min',
            onChanged: (v) => setState(() => _short = v),
          ),
          const SizedBox(height: 14),
          _DurationSetting(
            label: 'Long Break',
            value: _long,
            min: 5,
            max: 60,
            suffix: 'min',
            onChanged: (v) => setState(() => _long = v),
          ),
          const SizedBox(height: 20),
          Text('Completion Sound', style: AppTextStyles.label),
          const SizedBox(height: 4),
          Text(
            'Plays once when a phase ends. Ambient track stops automatically.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: widget.vm,
            builder: (_, __) => SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.vm.completionSounds.length,
                itemBuilder: (context, index) {
                  final sound = widget.vm.completionSounds[index];
                  final selected = widget.vm.selectedCompletionSound == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => widget.vm.selectCompletionSound(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.accentSoft
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? AppColors.accent
                                : AppColors.surfaceBorder,
                            width: selected ? 1 : 0.6,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(sound['icon'] ?? ''),
                            const SizedBox(width: 6),
                            Text(
                              sound['label'] ?? '',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                widget.vm.updateSettings(
                    focus: _focus, shortBreak: _short, longBreak: _long);
                Navigator.pop(context);
              },
              child: const Text('Apply Settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusModeOverlay extends StatefulWidget {
  final TimerViewModel vm;
  const _FocusModeOverlay({required this.vm});

  @override
  State<_FocusModeOverlay> createState() => _FocusModeOverlayState();
}

class _FocusModeOverlayState extends State<_FocusModeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
      lowerBound: 0.04,
      upperBound: 0.12,
    )..repeat(reverse: true);
    _scheduleControlsHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _glowController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleControlsHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleControlsHide();
  }

  String _overlayBreakTip() {
    const tips = [
      'Stretch your arms and neck 🙆',
      'Grab a glass of water 💧',
      'Rest your eyes — look away 👀',
      'Take a few deep breaths 🌬️',
      'Stand up and move around 🚶',
      'Close your eyes for a moment 😌',
    ];
    return tips[DateTime.now().second % tips.length];
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return GestureDetector(
      onTap: _toggleControls,
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 12) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: AnimatedBuilder(
          animation: Listenable.merge([_glowController, vm]),
          builder: (_, __) {
            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accent.withOpacity(_glowController.value),
                          AppColors.primary,
                        ],
                        radius: 0.85,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _showControls ? 1 : 0,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header: subject or break label ──────────────────
                      Text(
                        vm.phase == TimerPhase.focus
                            ? vm.selectedSubject
                            : vm.phase == TimerPhase.longBreak
                                ? '☕ Long Break'
                                : '🧘 Short Break',
                        style: AppTextStyles.h3.copyWith(color: Colors.white),
                      ),
                      if (vm.phase != TimerPhase.focus) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Returning to: ${vm.selectedSubject}',
                          style: AppTextStyles.caption
                              .copyWith(color: Colors.white54),
                        ),
                      ],
                      const SizedBox(height: 22),

                      // ── Circular timer ring (phase label shown inside) ──
                      SizedBox(width: 240, child: _CircularTimer(vm: vm)),
                      const SizedBox(height: 18),

                      // ── Contextual sub-message (replaces duplicate label)
                      if (vm.phase != TimerPhase.focus)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _overlayBreakTip(),
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white70),
                          ),
                        )
                      else
                        Text(
                          '${vm.sessionsCompleted} session${vm.sessionsCompleted == 1 ? '' : 's'} done',
                          style: AppTextStyles.caption
                              .copyWith(color: Colors.white38),
                        ),
                      const SizedBox(height: 24),

                      // ── Controls: phase-aware ────────────────────────────
                      if (vm.phase != TimerPhase.focus) ...[
                        // Study Now pill
                        GestureDetector(
                          onTap: vm.skip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.school_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Study Now',
                                  style: AppTextStyles.label.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Smaller pause/resume (secondary)
                        GestureDetector(
                          onTap: vm.isRunning ? vm.pause : vm.start,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Icon(
                              vm.isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'or keep resting',
                          style: AppTextStyles.caption
                              .copyWith(color: Colors.white38),
                        ),
                      ] else ...[
                        // Focus mode: big play/pause only
                        GestureDetector(
                          onTap: vm.isRunning ? vm.pause : vm.start,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                              gradient: AppColors.accentGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              vm.isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DurationSetting extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _DurationSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.body)),
        Row(
          children: [
            GestureDetector(
              onTap: value > min ? () => onChanged(value - 1) : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: AppColors.surfaceElevated, shape: BoxShape.circle),
                child: Icon(Icons.remove,
                    size: 16,
                    color:
                        value > min ? AppColors.accent : AppColors.textMuted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('$value $suffix',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.accent, fontWeight: FontWeight.w600)),
            ),
            GestureDetector(
              onTap: value < max ? () => onChanged(value + 1) : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: AppColors.surfaceElevated, shape: BoxShape.circle),
                child: Icon(Icons.add,
                    size: 16,
                    color:
                        value < max ? AppColors.accent : AppColors.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
