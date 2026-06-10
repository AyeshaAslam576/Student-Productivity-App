import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/widgets/brainup_shimmer.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../../../core/widgets/brainup_empty_state.dart';
import '../../../core/widgets/brainup_error_state.dart';
import '../../../core/utils/validators.dart';
import '../models/attendance_model.dart';
import '../viewmodels/attendance_viewmodel.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AttendanceViewModel>();
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _AttendanceAppBar(onAdd: () => _showAddSubject(context, vm)),
            Expanded(
              child: vm.isLoading
                  ? const Padding(padding: EdgeInsets.all(20), child: ShimmerList(count: 4))
                  : vm.error != null
                      ? BrainUpErrorState(message: vm.error, onRetry: vm.loadAttendance)
                      : _AttendanceBody(
                          vm: vm,
                          onAdd: () => _showAddSubject(context, vm),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubject(BuildContext ctx, AttendanceViewModel vm) {
    final nameCtrl = TextEditingController();
    final suggestions = vm.subjectSuggestions;
    final rootMessenger = ScaffoldMessenger.of(ctx);

    void setName(String s) {
      nameCtrl.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }

    Future<void> submit(BuildContext dialogCtx) async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        rootMessenger.showSnackBar(
          const SnackBar(content: Text('Please enter a subject name')),
        );
        return;
      }
      final ok = await vm.addSubject(name);
      if (!dialogCtx.mounted) return;
      Navigator.pop(dialogCtx);
      rootMessenger.showSnackBar(
        SnackBar(
          content: Text(ok ? 'Added "$name"' : 'Failed to add subject'),
        ),
      );
    }

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Add Subject', style: ctx.text.h4),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (suggestions.isNotEmpty) ...[
                Text('From your timetable:',
                    style: ctx.text.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: suggestions
                      .map((s) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setName(s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: ctx.colors.accentSoft,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: ctx.colors.accent
                                        .withOpacity(0.3)),
                              ),
                              child: Text(
                                s,
                                style: ctx.text.caption.copyWith(
                                    color: ctx.colors.accent,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              BrainUpTextField(
                label: 'Subject Name',
                controller: nameCtrl,
                prefixIcon: const Icon(Icons.book_outlined),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(dialogCtx),
                validator: (v) =>
                    AppValidators.required(v, fieldName: 'Subject name'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => submit(dialogCtx),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _AttendanceAppBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _AttendanceAppBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
            bottom: BorderSide(color: context.colors.surfaceBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          brainUpBackButton(context,
              iconColor: context.colors.textPrimary),
          Text('Attendance', style: context.text.h3),
          const Spacer(),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Subject'),
          ),
        ],
      ),
    );
  }
}

class _AttendanceBody extends StatelessWidget {
  final AttendanceViewModel vm;
  final VoidCallback onAdd;
  const _AttendanceBody({required this.vm, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.surfaceCard,
      onRefresh: vm.loadAttendance,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // ─── Overall % ───
          BrainUpCard(
            gradient: colors.primaryGradient,
            child: Row(
              children: [
                CircularPercentIndicator(
                  radius: 56,
                  lineWidth: 8,
                  percent: (vm.overallPercentage / 100).clamp(0.0, 1.0),
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: vm.overallPercentage),
                        duration: const Duration(milliseconds: 800),
                        builder: (_, val, __) => Text(
                          '${val.toStringAsFixed(0)}%',
                          style: context.text.h4.copyWith(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  progressColor: _pctColor(context, vm.overallPercentage),
                  backgroundColor: colors.surfaceBorder,
                  circularStrokeCap: CircularStrokeCap.round,
                  animation: true,
                  animationDuration: 800,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overall Attendance', style: context.text.h4),
                      const SizedBox(height: 4),
                      Text('${vm.attendance.length} subjects tracked',
                          style: context.text.bodySmall),
                      const SizedBox(height: 12),
                      _StatusRow(
                        label: 'Safe',
                        count: vm.attendance.where((a) => a.isSafe).length,
                        color: colors.success,
                      ),
                      _StatusRow(
                        label: 'Warning',
                        count: vm.attendance.where((a) => a.isWarning).length,
                        color: colors.warning,
                      ),
                      _StatusRow(
                        label: 'Critical',
                        count: vm.attendance.where((a) => a.isCritical).length,
                        color: colors.error,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

          // ─── Warning Banner ───
          if (vm.criticalSubjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: colors.warning.withOpacity(0.4), width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: colors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚠  ${vm.criticalSubjects.map((a) => a.subjectName).join(", ")} — attendance critical',
                      style: context.text.bodySmall
                          .copyWith(color: colors.warning),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 100.ms).fadeIn(),
          ],

          const SizedBox(height: 20),

          if (vm.attendance.isEmpty)
            BrainUpEmptyState(
              variant: EmptyStateVariant.attendance,
              actionLabel: 'Add Subject',
              onAction: onAdd,
            )
          else ...[
            Text('Subject Wise', style: context.text.h4),
            const SizedBox(height: 12),
            ...vm.attendance.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SubjectAttendanceCard(
                  model: e.value,
                  onMark: (status) async { await vm.markAttendance(e.value.id, status); },
                  onDelete: () => vm.deleteSubject(e.value.id),
                ).animate(delay: (e.key * 60).ms).fadeIn(duration: 300.ms).slideY(begin: 0.05),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _pctColor(BuildContext context, double pct) {
    if (pct >= 75) return context.colors.success;
    if (pct >= 65) return context.colors.warning;
    return context.colors.error;
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatusRow({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label: $count', style: context.text.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _SubjectAttendanceCard extends StatefulWidget {
  final AttendanceModel model;
  final Future<void> Function(String) onMark;
  final VoidCallback onDelete;

  const _SubjectAttendanceCard({
    required this.model,
    required this.onMark,
    required this.onDelete,
  });

  @override
  State<_SubjectAttendanceCard> createState() => _SubjectAttendanceCardState();
}

class _SubjectAttendanceCardState extends State<_SubjectAttendanceCard> {
  bool _isSaving = false;

  Future<void> _mark(String status) async {
    setState(() => _isSaving = true);
    await widget.onMark(status);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = widget.model;
    final pct = m.percentage;
    final color = pct >= 75
        ? colors.success
        : pct >= 65
            ? colors.warning
            : colors.error;

    return BrainUpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(m.subjectName,
                    style: context.text.h5, overflow: TextOverflow.ellipsis),
              ),
              CircularPercentIndicator(
                radius: 28,
                lineWidth: 5,
                percent: (pct / 100).clamp(0.0, 1.0),
                center: Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: context.text.caption.copyWith(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
                progressColor: color,
                backgroundColor: colors.surfaceBorder,
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: [
              _StatBadge(label: 'Present', value: m.present, color: colors.success),
              const SizedBox(width: 8),
              _StatBadge(label: 'Absent', value: m.absent, color: colors.error),
              const SizedBox(width: 8),
              _StatBadge(
                  label: 'Total',
                  value: m.totalClasses,
                  color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: 8),
          // Advice text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              m.isSafe
                  ? 'Safe to miss ${m.safeToMiss} more class${m.safeToMiss == 1 ? '' : 'es'}'
                  : 'Must attend ${m.mustAttendToRecover} more class${m.mustAttendToRecover == 1 ? '' : 'es'} to reach 75%',
              style: context.text.caption.copyWith(color: color),
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _isSaving
                    ? Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: colors.accent)))
                    : Row(
                        children: [
                          Expanded(
                            child: _MarkButton(
                              label: 'Present',
                              icon: Icons.check_circle_rounded,
                              color: colors.success,
                              onTap: () => _mark('present'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MarkButton(
                              label: 'Absent',
                              icon: Icons.cancel_rounded,
                              color: colors.error,
                              onTap: () => _mark('absent'),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onDelete,
                icon: Icon(Icons.delete_outline,
                    size: 18, color: colors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MarkButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: context.text.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text('$value', style: context.text.label.copyWith(color: color)),
          Text(label, style: context.text.caption.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}
