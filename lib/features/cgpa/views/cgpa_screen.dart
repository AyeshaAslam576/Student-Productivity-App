import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/widgets/brainup_shimmer.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../../../core/widgets/brainup_empty_state.dart';
import '../../../core/widgets/brainup_error_state.dart';
import '../models/semester_model.dart';
import '../models/subject_grade_model.dart';
import '../viewmodels/cgpa_viewmodel.dart';

class CgpaScreen extends StatelessWidget {
  const CgpaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CgpaViewModel>();
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _CgpaAppBar(onAdd: () => _showAddSemester(context, vm)),
            Expanded(
              child: vm.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20), child: ShimmerList(count: 3))
                  : (vm.error != null && vm.semesters.isEmpty)
                      ? BrainUpErrorState(
                          message:
                              'Could not load your data. Showing cached results if available.',
                          onRetry: vm.loadSemesters,
                        )
                      : _CgpaBody(
                          vm: vm, onAdd: () => _showAddSemester(context, vm)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSemester(BuildContext context, CgpaViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const AddSemesterSheet(),
      ),
    );
  }
}

class _CgpaAppBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _CgpaAppBar({required this.onAdd});

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
          Flexible(
            child: Text(
              'CGPA Calculator',
              style: context.text.h3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Semester'),
          ),
        ],
      ),
    );
  }
}

class _CgpaBody extends StatelessWidget {
  final CgpaViewModel vm;
  final VoidCallback onAdd;
  const _CgpaBody({required this.vm, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surfaceCard,
      onRefresh: vm.loadSemesters,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          if (vm.error != null && vm.semesters.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 14, color: context.colors.warning),
                  const SizedBox(width: 8),
                  Text(
                    'Offline — showing cached data',
                    style: context.text.caption
                        .copyWith(color: context.colors.warning),
                  ),
                ],
              ),
            ),
          // ─── Header CGPA Card ───
          BrainUpCard(
            gradient: context.colors.primaryGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current CGPA', style: context.text.bodySmall),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: vm.cgpa),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder: (_, val, __) => Text(
                        val.toStringAsFixed(2),
                        style: context.text.display,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Text('/ 4.00', style: context.text.bodySmall),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${vm.semesters.length} Semesters',
                            style: context.text.caption),
                        Text('${vm.totalCredits} Credit Hours',
                            style: context.text.caption),
                      ],
                    ),
                  ],
                ),
                if (vm.semesters.length > 1) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 60,
                    child: _CgpaSparkline(vm: vm),
                  ),
                ],
                const SizedBox(height: 12),
                _GoalTrackerRow(vm: vm),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

          const SizedBox(height: 20),

          if (vm.semesters.isEmpty)
            BrainUpEmptyState(
              variant: EmptyStateVariant.cgpa,
              actionLabel: 'Add Semester',
              onAction: onAdd,
            )
          else ...[
            if (vm.semesters.length >= 2) ...[
              _BestWorstBanner(vm: vm),
              const SizedBox(height: 14),
            ],
            Text('Semester History', style: context.text.h4),
            const SizedBox(height: 12),
            ...vm.semesters.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SemesterCard(
                      semester: e.value,
                      isExpanded: vm.isExpanded(e.value.id),
                      onToggle: () => vm.toggleExpand(e.value.id),
                      onDelete: () => vm.deleteSemester(e.value.id),
                    )
                        .animate(delay: (e.key * 60).ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.05),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _CgpaSparkline extends StatelessWidget {
  final CgpaViewModel vm;
  const _CgpaSparkline({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.cgpaTrend.length < 2) return const SizedBox();
    final spots = vm.cgpaTrend.map((d) => FlSpot(d.x, d.y)).toList();
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 4,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: context.colors.accent,
            barWidth: 2,
            dotData: FlDotData(
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: context.colors.accent,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.colors.accent.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemesterCard extends StatelessWidget {
  final SemesterModel semester;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _SemesterCard({
    required this.semester,
    required this.isExpanded,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.surfaceBorder, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                  width: 4, color: _semesterAccent(context, semester.gpa)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                children: [
                  InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(semester.name, style: context.text.h5),
                                Text(
                                    '${semester.session} ${semester.year} · ${semester.totalCredits} credits',
                                    style: context.text.caption),
                                const SizedBox(height: 6),
                                Row(
                                  children: semester.subjects
                                      .take(6)
                                      .map(
                                        (s) => Container(
                                          width: 8,
                                          height: 8,
                                          margin:
                                              const EdgeInsets.only(right: 3),
                                          decoration: BoxDecoration(
                                            color: _gradeColor(context, s.grade),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.colors.accentSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'GPA ${semester.gpa.toStringAsFixed(2)}',
                              style: context.text.label
                                  .copyWith(color: context.colors.accent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: context.colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    Divider(height: 0, color: context.colors.surfaceBorder),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text('Subject',
                                        style: context.text.caption)),
                                SizedBox(
                                    width: 40,
                                    child: Text('CH',
                                        style: context.text.caption,
                                        textAlign: TextAlign.center)),
                                SizedBox(
                                    width: 44,
                                    child: Text('Grade',
                                        style: context.text.caption,
                                        textAlign: TextAlign.center)),
                                SizedBox(
                                    width: 36,
                                    child: Text('GP',
                                        style: context.text.caption,
                                        textAlign: TextAlign.center)),
                              ],
                            ),
                          ),
                          Divider(color: context.colors.surfaceBorder),
                          ...semester.subjects.map(
                            (sub) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Text(sub.name,
                                              style: context.text.body,
                                              overflow: TextOverflow.ellipsis)),
                                      SizedBox(
                                          width: 40,
                                          child: Text('${sub.creditHours}',
                                              style: context.text.body,
                                              textAlign: TextAlign.center)),
                                      SizedBox(
                                        width: 44,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _gradeColor(
                                                      context, sub.grade)
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(sub.grade,
                                                style: context.text.labelSmall
                                                    .copyWith(
                                                        color: _gradeColor(
                                                            context,
                                                            sub.grade))),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                          width: 36,
                                          child: Text(
                                              sub.gradePoints
                                                  .toStringAsFixed(1),
                                              style: context.text.body,
                                              textAlign: TextAlign.center)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: sub.gradePoints / 4.0,
                                    backgroundColor: context.colors.surfaceElevated,
                                    valueColor: AlwaysStoppedAnimation(
                                        _gradeColor(context, sub.grade)),
                                    borderRadius: BorderRadius.circular(4),
                                    minHeight: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(color: context.colors.surfaceBorder),
                          Row(
                            children: [
                              Expanded(
                                  child: Text('Total',
                                      style: TextStyle(
                                          color: context.colors.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600))),
                              SizedBox(
                                  width: 40,
                                  child: Text('${semester.totalCredits}',
                                      style: context.text.label
                                          .copyWith(color: context.colors.accent),
                                      textAlign: TextAlign.center)),
                              const SizedBox(width: 44),
                              SizedBox(
                                  width: 36,
                                  child: Text(semester.gpa.toStringAsFixed(2),
                                      style: context.text.label
                                          .copyWith(color: context.colors.accent),
                                      textAlign: TextAlign.center)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: context.colors.surfaceCard,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  builder: (_) => Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.warning_amber_rounded,
                                            color: context.colors.error, size: 36),
                                        const SizedBox(height: 12),
                                        Text('Delete ${semester.name}?',
                                            style: context.text.h4),
                                        const SizedBox(height: 6),
                                        Text(
                                          'This will permanently delete all ${semester.subjects.length} subjects.',
                                          style: context.text.body,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: BrainUpButton.secondary(
                                                label: 'Cancel',
                                                onTap: () =>
                                                    Navigator.pop(context),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: BrainUpButton(
                                                label: 'Delete',
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  onDelete();
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.delete_outline,
                                  size: 16, color: context.colors.error),
                              label: Text('Delete Semester',
                                  style: TextStyle(
                                      color: context.colors.error, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _gradeColor(BuildContext context, String grade) {
    final gp = SubjectGradeModel.gradePointsFromGrade(grade);
    if (gp >= 3.5) return context.colors.success;
    if (gp >= 2.5) return context.colors.warning;
    if (gp >= 1.0) return context.colors.error;
    return context.colors.error;
  }

  Color _semesterAccent(BuildContext context, double gpa) {
    if (gpa >= 3.5) return context.colors.success;
    if (gpa >= 3.0) return const Color(0xFF00BFA5);
    if (gpa >= 2.5) return context.colors.warning;
    if (gpa >= 2.0) return Colors.orange;
    return context.colors.error;
  }
}

class _BestWorstBanner extends StatelessWidget {
  final CgpaViewModel vm;
  const _BestWorstBanner({required this.vm});

  @override
  Widget build(BuildContext context) {
    final best = vm.semesters.reduce((a, b) => a.gpa >= b.gpa ? a : b);
    final worst = vm.semesters.reduce((a, b) => a.gpa <= b.gpa ? a : b);
    return Row(
      children: [
        Expanded(
          child: BrainUpCard(
            gradient: LinearGradient(
              colors: [
                context.colors.success.withOpacity(0.08),
                context.colors.surfaceCard,
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded,
                        color: context.colors.success, size: 18),
                    const SizedBox(width: 6),
                    Text('Best Semester', style: context.text.label),
                  ],
                ),
                const SizedBox(height: 8),
                Text(best.name,
                    style: context.text.h5,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('GPA ${best.gpa.toStringAsFixed(2)}',
                    style:
                        context.text.body.copyWith(color: context.colors.success)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BrainUpCard(
            gradient: LinearGradient(
              colors: [
                context.colors.error.withOpacity(0.08),
                context.colors.surfaceCard,
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_down_rounded,
                        color: context.colors.error, size: 18),
                    const SizedBox(width: 6),
                    Text('Needs Focus', style: context.text.label),
                  ],
                ),
                const SizedBox(height: 8),
                Text(worst.name,
                    style: context.text.h5,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('GPA ${worst.gpa.toStringAsFixed(2)}',
                    style: context.text.body.copyWith(color: context.colors.error)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalTrackerRow extends StatelessWidget {
  final CgpaViewModel vm;
  const _GoalTrackerRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.targetCgpa == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => _showGoalDialog(context),
          child: const Text('Set CGPA Goal'),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surfaceCard.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_rounded, color: context.colors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(vm.targetInsight, style: context.text.bodySmall)),
          TextButton(
            onPressed: () => _showGoalDialog(context),
            style: TextButton.styleFrom(
                minimumSize: Size.zero, padding: EdgeInsets.zero),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showGoalDialog(BuildContext context) async {
    final min = (vm.cgpa + 0.1).clamp(0.1, 4.0);
    double current = vm.targetCgpa?.clamp(min, 4.0) ?? min;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setLocal) => AlertDialog(
            backgroundColor: context.colors.surfaceCard,
            title: Text('Set CGPA Goal', style: context.text.h4),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Target: ${current.toStringAsFixed(1)}',
                    style: context.text.body),
                Slider(
                  min: min,
                  max: 4.0,
                  divisions: 29,
                  value: current,
                  onChanged: (v) => setLocal(() => current = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  vm.setTargetCgpa(current);
                  Navigator.pop(dialogContext);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── ADD SEMESTER SHEET ──────────────────────────────────────────────────────

class AddSemesterSheet extends StatefulWidget {
  const AddSemesterSheet({super.key});
  @override
  State<AddSemesterSheet> createState() => _AddSemesterSheetState();
}

class _AddSemesterSheetState extends State<AddSemesterSheet> {
  final _nameCtrl = TextEditingController();
  final _yearCtrl = TextEditingController(text: DateTime.now().year.toString());
  String _session = 'Fall';
  final List<_SubjectEntry> _subjects = [];
  double _previewGpa = 0;

  final _sessions = ['Fall', 'Spring', 'Summer'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _addSubject() {
    setState(() => _subjects.add(_SubjectEntry()));
    _recalcGpa();
  }

  void _recalcGpa() {
    final subs = _subjects
        .where((s) => s.grade != null && s.creditHours > 0)
        .map((s) => SubjectGradeModel(
              id: '',
              name: s.nameCtrl.text,
              creditHours: s.creditHours,
              grade: s.grade!,
              gradePoints: SubjectGradeModel.gradePointsFromGrade(s.grade!),
            ))
        .toList();
    setState(() => _previewGpa = SemesterModel.calculateGpa(subs));
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final subs = _subjects
        .where((s) => s.grade != null && s.nameCtrl.text.trim().isNotEmpty)
        .map((s) => SubjectGradeModel(
              id: '',
              name: s.nameCtrl.text.trim(),
              creditHours: s.creditHours,
              grade: s.grade!,
              gradePoints: SubjectGradeModel.gradePointsFromGrade(s.grade!),
            ))
        .toList();

    final semester = SemesterModel(
      id: '',
      name: _nameCtrl.text.trim(),
      year: int.tryParse(_yearCtrl.text) ?? DateTime.now().year,
      session: _session,
      gpa: SemesterModel.calculateGpa(subs),
      totalCredits: subs.fold(0, (s, e) => s + e.creditHours),
      createdAt: DateTime.now(),
      subjects: subs,
    );
    final vm = context.read<CgpaViewModel>();
    final ok = await vm.addSemester(semester);
    if (!mounted || !ok) return;
    Navigator.pop(context);
    if (!mounted) return;
    await _showMotivationSheet(context, vm, semester.gpa);
  }

  Future<void> _showMotivationSheet(
      BuildContext context, CgpaViewModel vm, double gpa) async {
    if (vm.isLoadingMotivation) return;
    if (vm.aiMotivation == null || vm.aiMotivation!.trim().isEmpty) return;
    final color = _motivationColor(gpa);
    final emoji = _motivationEmoji(gpa);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final colors = sheetCtx.colors;
        final text = sheetCtx.text;
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: color.withOpacity(0.6), width: 3),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 42)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      vm.aiMotivation ?? '',
                      style: text.bodyLarge.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...vm.aiTips.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${e.key + 1}. ${e.value}',
                                  style: text.bodyLarge.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if ((vm.aiGoal ?? '').isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 6, bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.35)),
                      ),
                      child: Text(
                        'Goal: ${vm.aiGoal}',
                        style: text.bodyLarge.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  BrainUpButton(
                    label: 'Keep Going!',
                    onTap: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    vm.clearMotivation();
  }

  Color _motivationColor(double gpa) {
    if (gpa >= 3.5) return context.colors.success;
    if (gpa >= 3.0) return const Color(0xFF00BFA5);
    if (gpa >= 2.5) return context.colors.warning;
    return context.colors.error;
  }

  String _motivationEmoji(double gpa) {
    if (gpa >= 3.5) return '🌟';
    if (gpa >= 3.0) return '💪';
    if (gpa >= 2.5) return '🧡';
    return '❤️';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CgpaViewModel>();
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: context.colors.surfaceBorder,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Add Semester', style: context.text.h4),
                const Spacer(),
                if (_previewGpa > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: context.colors.accentSoft,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('GPA ${_previewGpa.toStringAsFixed(2)}',
                        style: context.text.label
                            .copyWith(color: context.colors.accent)),
                  ),
                const SizedBox(width: 8),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrainUpTextField(
                      label: 'Semester Name (e.g. Semester 1)',
                      controller: _nameCtrl,
                      prefixIcon: const Icon(Icons.school_outlined)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: BrainUpTextField(
                              label: 'Year',
                              controller: _yearCtrl,
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _session,
                          dropdownColor: context.colors.surfaceCard,
                          style: context.text.body,
                          decoration: InputDecoration(
                            labelText: 'Session',
                            filled: true,
                            fillColor: context.colors.surfaceElevated,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: context.colors.surfaceBorder)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: context.colors.surfaceBorder,
                                    width: 0.5)),
                          ),
                          items: _sessions
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) => setState(() => _session = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Subjects', style: context.text.h4),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addSubject,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_subjects.isEmpty)
                    Center(
                        child: Text('Tap Add to add subjects',
                            style: context.text.bodySmall))
                  else
                    ..._subjects.asMap().entries.map((e) => _SubjectRow(
                          entry: e.value,
                          onDelete: () => setState(() {
                            _subjects.removeAt(e.key);
                            _recalcGpa();
                          }),
                          onChanged: _recalcGpa,
                        )),
                  const SizedBox(height: 24),
                  BrainUpButton(
                    label: 'Save Semester',
                    isLoading: vm.isSaving,
                    onTap: vm.isSaving ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectEntry {
  final nameCtrl = TextEditingController();
  int creditHours = 3;
  String? grade;
}

class _SubjectRow extends StatefulWidget {
  final _SubjectEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  const _SubjectRow(
      {required this.entry, required this.onDelete, required this.onChanged});
  @override
  State<_SubjectRow> createState() => _SubjectRowState();
}

class _SubjectRowState extends State<_SubjectRow> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BrainUpCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.entry.nameCtrl,
                    style: context.text.body,
                    decoration: const InputDecoration(
                      hintText: 'Subject name',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => widget.onChanged(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: context.colors.error),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Credits:', style: context.text.caption),
                const SizedBox(width: 8),
                _Stepper(
                  value: widget.entry.creditHours,
                  min: 1,
                  max: 6,
                  onChanged: (v) {
                    setState(() => widget.entry.creditHours = v);
                    widget.onChanged();
                  },
                ),
                const Spacer(),
                Text('Grade:', style: context.text.caption),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: widget.entry.grade,
                  hint: Text('--',
                      style:
                          TextStyle(color: context.colors.textMuted, fontSize: 13)),
                  dropdownColor: context.colors.surfaceCard,
                  style: context.text.body.copyWith(color: context.colors.accent),
                  underline: const SizedBox(),
                  items: SubjectGradeModel.allGrades
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => widget.entry.grade = v);
                    widget.onChanged();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _Stepper(
      {required this.value,
      required this.min,
      required this.max,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: value > min ? () => onChanged(value - 1) : null,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: context.colors.surfaceElevated, shape: BoxShape.circle),
            child: Icon(Icons.remove,
                size: 14,
                color: value > min ? context.colors.accent : context.colors.textMuted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('$value',
              style: context.text.body.copyWith(
                  color: context.colors.accent, fontWeight: FontWeight.w600)),
        ),
        GestureDetector(
          onTap: value < max ? () => onChanged(value + 1) : null,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: context.colors.surfaceElevated, shape: BoxShape.circle),
            child: Icon(Icons.add,
                size: 14,
                color: value < max ? context.colors.accent : context.colors.textMuted),
          ),
        ),
      ],
    );
  }
}
