import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/widgets/brainup_shimmer.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../../../core/widgets/brainup_badge.dart';
import '../../../core/widgets/brainup_chip.dart';
import '../../../core/widgets/brainup_empty_state.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/services/lecture_notification_service.dart';
import '../models/lecture_model.dart';
import '../viewmodels/timetable_viewmodel.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<TimetableViewModel>();
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _TimetableAppBar(
              onAdd: () => _showAddSheet(context, vm),
              vm: vm,
            ),
            Container(
              color: colors.surfaceCard,
              child: TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'Week View'),
                  Tab(text: 'Today'),
                ],
              ),
            ),
            Expanded(
              child: vm.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: ShimmerList(count: 4),
                    )
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _WeekView(
                          vm: vm,
                          onAddTimetable: () => _showAddSheet(context, vm),
                        ),
                        _TodayView(vm: vm),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext ctx, TimetableViewModel vm) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const AddTimetableSheet(),
      ),
    );
  }
}

class _TimetableAppBar extends StatelessWidget {
  final VoidCallback onAdd;
  final TimetableViewModel vm;
  const _TimetableAppBar({required this.onAdd, required this.vm});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.surfaceBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text('Timetable', style: text.h3),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Timetable options',
            color: colors.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.surfaceBorder, width: 0.5),
            ),
            icon: Icon(Icons.more_vert_rounded,
                color: colors.textSecondary, size: 22),
            onSelected: (value) {
              switch (value) {
                case 'add':
                  onAdd();
                  break;
                case 'notifications':
                  _showNotificationSettings(context, vm);
                  break;
                case 'reset':
                  _confirmReset(context, vm);
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'add',
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_rounded,
                        color: colors.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text('Add lecture', style: text.body),
                ]),
              ),
              PopupMenuItem(
                value: 'notifications',
                child: Row(children: [
                  Icon(Icons.notifications_outlined,
                      color: colors.textSecondary, size: 20),
                  const SizedBox(width: 14),
                  Text('Notification settings', style: text.body),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'reset',
                child: Row(children: [
                  Icon(Icons.delete_sweep_rounded,
                      color: colors.error, size: 20),
                  const SizedBox(width: 14),
                  Text('Reset timetable',
                      style: text.body.copyWith(color: colors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings(BuildContext ctx, TimetableViewModel vm) {
    final colors = ctx.colors;
    final text = ctx.text;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          controller: scrollCtrl,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: colors.surfaceBorder,
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Notification Settings', style: text.h4),
            const SizedBox(height: 20),
            _NotifSettingRow(
              icon: Icons.alarm_rounded,
              title: '15-min Warning',
              subtitle: 'Alert before each lecture starts',
              prefKey: 'notif_15min',
              color: colors.warning,
              onChanged: (_) => LectureNotificationService
                  .rescheduleAllForTimetable(vm.lectures),
            ),
            const SizedBox(height: 12),
            _NotifSettingRow(
              icon: Icons.play_circle_outline_rounded,
              title: 'Lecture Start Alert',
              subtitle: 'With motivational quote + full details',
              prefKey: 'notif_start',
              color: colors.accent,
              onChanged: (_) => LectureNotificationService
                  .rescheduleAllForTimetable(vm.lectures),
            ),
            const SizedBox(height: 12),
            _NotifSettingRow(
              icon: Icons.free_breakfast_rounded,
              title: 'Break Time Reminder',
              subtitle: 'Between consecutive lectures',
              prefKey: 'notif_break',
              color: colors.success,
              onChanged: (_) => LectureNotificationService
                  .rescheduleAllForTimetable(vm.lectures),
            ),
            const SizedBox(height: 12),
            _NotifSettingRow(
              icon: Icons.wb_sunny_rounded,
              title: 'Morning Digest',
              subtitle: "Today's schedule at 8:00 AM",
              prefKey: 'notif_morning',
              color: colors.warning,
              onChanged: (_) => LectureNotificationService
                  .rescheduleAllForTimetable(vm.lectures),
            ),
            const SizedBox(height: 12),
            _NotifSettingRow(
              icon: Icons.fact_check_outlined,
              title: 'Class finished',
              subtitle:
                  'When each class ends — quick Present / Absent (Android)',
              prefKey: 'notif_lecture_end',
              color: colors.info,
              onChanged: (_) => LectureNotificationService
                  .rescheduleAllForTimetable(vm.lectures),
            ),
            const SizedBox(height: 24),
            BrainUpButton(
              label: 'Reschedule All Notifications',
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              onTap: () async {
                Navigator.pop(ctx);
                await LectureNotificationService.rescheduleAllForTimetable(vm.lectures);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: const Text('✅ Notifications rescheduled for 4 weeks'),
                    backgroundColor: colors.success,
                  ));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
        ),
      ),
      ),
    );
  }

  void _confirmReset(BuildContext ctx, TimetableViewModel vm) {
    final colors = ctx.colors;
    final text = ctx.text;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: colors.error, size: 40),
            const SizedBox(height: 12),
            Text('Reset Timetable?', style: text.h4),
            const SizedBox(height: 8),
            Text(
              'All lectures and notifications will be deleted permanently.',
              style: text.bodySmall.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: BrainUpButton.secondary(
                    label: 'Cancel',
                    onTap: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrainUpButton(
                    label: 'Reset',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await vm.resetTimetable();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── TODAY VIEW ─────────────────────────────────────────────────────────────

class _TodayView extends StatelessWidget {
  final TimetableViewModel vm;
  const _TodayView({required this.vm});

  @override
  Widget build(BuildContext context) {
    final lectures = vm.todayLectures;
    if (lectures.isEmpty) {
      return const BrainUpEmptyState(
        variant: EmptyStateVariant.timetable,
        title: 'No classes today',
        subtitle: 'Enjoy your free day! 🎉',
      );
    }
    return Column(
      children: [
        _NowNextBanner(vm: vm),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lectures.length,
            itemBuilder: (_, i) {
              final lec = lectures[i];
              return GestureDetector(
                onLongPress: () => _showLectureOptions(context, vm, lec),
                child: _TimelineCard(
                    lecture: lec, isLast: i == lectures.length - 1)
                    .animate(delay: (i * 60).ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.05),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showLectureOptions(
      BuildContext ctx, TimetableViewModel vm, LectureModel lecture) {
    final colors = ctx.colors;
    final text = ctx.text;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: colors.surfaceBorder,
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(lecture.subject, style: text.h4),
            Text(
              '${lecture.day} • ${lecture.startTime}–${lecture.endTime}',
              style: text.bodySmall.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(children: [
              _DetailChip(Icons.location_on_outlined, lecture.room),
              const SizedBox(width: 8),
              _DetailChip(Icons.person_outline, lecture.teacher),
              const SizedBox(width: 8),
              BrainUpTypeBadge(type: lecture.type),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Icon(Icons.notifications_outlined,
                  color: colors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lecture Notifications',
                        style: text.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text('15-min warning + start alert + break reminder',
                        style: text.caption),
                  ],
                ),
              ),
              Switch(
                value: lecture.notificationsEnabled,
                activeThumbColor: colors.accent,
                activeTrackColor: colors.accentSoft,
                onChanged: (v) {
                  Navigator.pop(ctx);
                  vm.toggleLectureNotification(lecture.id, v);
                },
              ),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: vm,
                    child: _LectureEditSheet(lecture: lecture),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Icon(Icons.edit_outlined,
                      color: colors.accent, size: 20),
                  const SizedBox(width: 12),
                  Text('Edit Lecture',
                      style: text.body.copyWith(color: colors.accent)),
                ]),
              ),
            ),
            Divider(height: 1, color: colors.surfaceBorder),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx); // close options sheet
                showModalBottomSheet(
                  context: ctx,
                  backgroundColor: Colors.transparent,
                  builder: (_) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(child: Container(width: 40, height: 4,
                          decoration: BoxDecoration(color: colors.surfaceBorder,
                            borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 20),
                        Icon(Icons.delete_outline_rounded,
                            color: colors.error, size: 40),
                        const SizedBox(height: 12),
                        Text('Delete Lecture?', style: text.h4),
                        const SizedBox(height: 8),
                        Text(
                          '${lecture.subject} • ${lecture.day} ${lecture.startTime}',
                          style: text.bodySmall.copyWith(
                              color: colors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lecture notifications will also be cancelled.',
                          style: text.caption.copyWith(
                              color: colors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(children: [
                          Expanded(
                            child: BrainUpButton.secondary(
                              label: 'Cancel',
                              onTap: () => Navigator.pop(ctx),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BrainUpButton(
                              label: 'Delete',
                              onTap: () {
                                Navigator.pop(ctx);
                                vm.deleteLecture(lecture.id);
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      color: colors.error, size: 20),
                  const SizedBox(width: 12),
                  Text('Delete Lecture',
                      style: text.body.copyWith(color: colors.error)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── EDIT LECTURE SHEET ──────────────────────────────────────────────────────

class _LectureEditSheet extends StatefulWidget {
  final LectureModel lecture;
  const _LectureEditSheet({required this.lecture});

  @override
  State<_LectureEditSheet> createState() => _LectureEditSheetState();
}

class _LectureEditSheetState extends State<_LectureEditSheet> {
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _teacherCtrl;
  late final TextEditingController _roomCtrl;
  late String _day;
  late String _startTime;
  late String _endTime;
  late String _type;
  bool _saving = false;

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  String _normalizeDay(String raw) {
    final v = raw.trim().toLowerCase();
    for (final d in _days) {
      if (v.startsWith(d.substring(0, 3).toLowerCase())) return d;
    }
    return 'Monday';
  }

  @override
  void initState() {
    super.initState();
    _subjectCtrl = TextEditingController(text: widget.lecture.subject);
    _teacherCtrl = TextEditingController(text: widget.lecture.teacher);
    _roomCtrl = TextEditingController(text: widget.lecture.room);
    _day = _normalizeDay(widget.lecture.day);
    _startTime = widget.lecture.startTime;
    _endTime = widget.lecture.endTime;
    _type = widget.lecture.type.toLowerCase() == 'lab' ? 'lab' : 'lecture';
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _teacherCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool start}) async {
    final current = (start ? _startTime : _endTime).split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.parse(current[0]), minute: int.parse(current[1])),
    );
    if (t == null) return;
    final formatted =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (start) {
        _startTime = formatted;
      } else {
        _endTime = formatted;
      }
    });
  }

  bool get _isValid {
    if (_subjectCtrl.text.trim().isEmpty) return false;
    final s = _startTime.split(':').map(int.parse).toList();
    final e = _endTime.split(':').map(int.parse).toList();
    return (e[0] * 60 + e[1]) > (s[0] * 60 + s[1]);
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    final vm = context.read<TimetableViewModel>();
    final updated = widget.lecture.copyWith(
      subject: _subjectCtrl.text.trim(),
      teacher: _teacherCtrl.text.trim(),
      room: _roomCtrl.text.trim(),
      day: _day,
      startTime: _startTime,
      endTime: _endTime,
      type: _type,
    );
    final ok = await vm.updateLecture(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    final colors = context.colors;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '✅ Lecture updated'
          : 'Could not update lecture. Try again.'),
      backgroundColor: ok ? colors.success : colors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Edit Lecture', style: text.h4),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: colors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BrainUpTextField(label: 'Subject', controller: _subjectCtrl),
              const SizedBox(height: 10),
              BrainUpTextField(label: 'Teacher', controller: _teacherCtrl),
              const SizedBox(height: 10),
              BrainUpTextField(label: 'Room', controller: _roomCtrl),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _days.contains(_day) ? _day : _days.first,
                dropdownColor: colors.surfaceCard,
                style: text.body,
                decoration: InputDecoration(
                  labelText: 'Day',
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: colors.surfaceBorder, width: 0.5),
                  ),
                ),
                items: _days
                    .map((d) =>
                        DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _day = v ?? _days.first),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _TimePicker(
                    label: 'Start',
                    time: _startTime,
                    onTap: () => _pickTime(start: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimePicker(
                    label: 'End',
                    time: _endTime,
                    onTap: () => _pickTime(start: false),
                  ),
                ),
              ]),
              if (!_isValid)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'End time must be after start time.',
                    style: text.caption.copyWith(color: colors.error),
                  ),
                ),
              const SizedBox(height: 12),
              Row(children: [
                ...['lecture', 'lab'].map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BrainUpChip(
                      label: t.toUpperCase(),
                      isSelected: _type == t,
                      onTap: () => setState(() => _type = t),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: BrainUpButton.secondary(
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrainUpButton(
                    label: _saving ? 'Saving…' : 'Save',
                    onTap: _isValid && !_saving ? _save : () {},
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TIMELINE CARD ───────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  final LectureModel lecture;
  final bool isLast;
  const _TimelineCard({required this.lecture, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final color = AppColors.subjectColor(lecture.subject);
    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Text(
                  AppDateUtils.timeFromString(lecture.startTime),
                  style: text.label.copyWith(color: colors.accent, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: isLast ? Colors.transparent : colors.surfaceBorder,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BrainUpCard(
                padding: EdgeInsets.zero,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border(left: BorderSide(color: color, width: 3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(lecture.subject, style: text.h5),
                            ),
                            BrainUpTypeBadge(type: lecture.type),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 13, color: colors.textMuted),
                            const SizedBox(width: 4),
                            Text(lecture.teacher, style: text.caption),
                            const SizedBox(width: 12),
                            Icon(Icons.location_on_outlined, size: 13, color: colors.textMuted),
                            const SizedBox(width: 4),
                            Text(lecture.room, style: text.caption),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppDateUtils.timeFromString(lecture.startTime)} – ${AppDateUtils.timeFromString(lecture.endTime)}',
                          style: text.label.copyWith(color: color, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── WEEK VIEW ───────────────────────────────────────────────────────────────

class _WeekView extends StatelessWidget {
  final TimetableViewModel vm;
  final VoidCallback onAddTimetable;
  const _WeekView({required this.vm, required this.onAddTimetable});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _startHour = 7;
  static const _endHour = 21;
  static const _cellWidth = 80.0;
  static const _timeHeaderWidth = 60.0;
  static const _rowHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    if (vm.lectures.isEmpty) {
      return BrainUpEmptyState(
        variant: EmptyStateVariant.timetable,
        actionLabel: 'Add Timetable',
        onAction: onAddTimetable,
      );
    }

    final colors = context.colors;
    final text = context.text;

    final totalWidth = _timeHeaderWidth + (_endHour - _startHour) * _cellWidth;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time header row
              Row(
                children: [
                  const SizedBox(width: _timeHeaderWidth, height: 36),
                  ...List.generate(_endHour - _startHour, (i) {
                    final hour = _startHour + i;
                    final label = hour < 12
                        ? '$hour AM'
                        : hour == 12
                            ? '12 PM'
                            : '${hour - 12} PM';
                    return Container(
                      width: _cellWidth,
                      height: 36,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: colors.surfaceBorder, width: 0.5),
                        ),
                      ),
                      child: Text(label,
                          style: text.caption.copyWith(fontSize: 10)),
                    );
                  }),
                ],
              ),
              // One row per day
              ..._days.map((day) => _buildDayRow(context, day)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayRow(BuildContext context, String day) {
    final colors = context.colors;
    final text = context.text;
    final now = DateTime.now();
    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final isToday = now.weekday <= weekDays.length &&
        day == weekDays[now.weekday - 1];
    final dayLectures = vm.lectures
        .where((l) => l.day.toLowerCase().startsWith(day.toLowerCase()))
        .toList();
    final gridWidth = (_endHour - _startHour) * _cellWidth;

    return SizedBox(
      height: _rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day label column
          Container(
            width: _timeHeaderWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: colors.surfaceBorder, width: 0.5),
                left: isToday
                    ? BorderSide(color: colors.accent, width: 2.5)
                    : BorderSide.none,
              ),
            ),
            child: Text(
              day,
              style: text.label.copyWith(
                color: isToday ? colors.accent : colors.textSecondary,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          // Grid + lecture blocks + time line
          Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Grid background lines
              SizedBox(
                width: gridWidth,
                height: _rowHeight,
                child: CustomPaint(
                  painter: _WeekGridPainter(
                    cellWidth: _cellWidth,
                    cellCount: _endHour - _startHour,
                    color: colors.surfaceBorder,
                  ),
                ),
              ),
              // Lecture blocks
              ..._buildDayLectureBlocks(context, dayLectures, vm),
              // Current time vertical line (today only)
              if (isToday) _buildCurrentTimeIndicator(context),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDayLectureBlocks(
    BuildContext context,
    List<LectureModel> lectures,
    TimetableViewModel vm,
  ) {
    final colors = context.colors;
    final text = context.text;
    return lectures.map((lec) {
      final left = ((lec.startMinutes / 60) - _startHour) * _cellWidth;
      final width = (lec.durationMinutes / 60) * _cellWidth - 4;
      final color = AppColors.subjectColor(lec.subject);
      final clampedWidth = width.clamp(20.0, double.infinity);
      final showInitialOnly = clampedWidth < 60;

      return Positioned(
        left: left,
        top: 4,
        width: clampedWidth,
        height: 64,
        child: GestureDetector(
          onTap: () => _showLectureDetailSheet(context, lec, vm),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: lec.isLab ? color : color.withOpacity(0.5),
                width: lec.isLab ? 1.5 : 0.8,
              ),
            ),
            child: showInitialOnly
                ? Center(
                    child: Text(
                      lec.subject.isNotEmpty ? lec.subject[0] : '?',
                      style: text.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        lec.subject,
                        style: text.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lec.room,
                        style: text.caption.copyWith(
                          fontSize: 9,
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
        ),
      );
    }).toList();
  }

  void _showLectureDetailSheet(
    BuildContext ctx,
    LectureModel lecture,
    TimetableViewModel vm,
  ) {
    final colors = ctx.colors;
    final text = ctx.text;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
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
                  color: colors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(lecture.subject, style: text.h4),
            Text(
              '${lecture.day} • ${lecture.startTime}–${lecture.endTime}',
              style: text.bodySmall.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(children: [
              _DetailChip(Icons.location_on_outlined, lecture.room),
              const SizedBox(width: 8),
              _DetailChip(Icons.person_outline, lecture.teacher),
              const SizedBox(width: 8),
              BrainUpTypeBadge(type: lecture.type),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Icon(Icons.notifications_outlined,
                  color: colors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lecture Notifications',
                      style: text.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '15-min warning + start alert + break reminder',
                      style: text.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: lecture.notificationsEnabled,
                activeThumbColor: colors.accent,
                activeTrackColor: colors.accentSoft,
                onChanged: (v) {
                  Navigator.pop(ctx);
                  vm.toggleLectureNotification(lecture.id, v);
                },
              ),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: vm,
                    child: _LectureEditSheet(lecture: lecture),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Icon(Icons.edit_outlined, color: colors.accent, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Lecture',
                    style: text.body.copyWith(color: colors.accent),
                  ),
                ]),
              ),
            ),
            Divider(height: 1, color: colors.surfaceBorder),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: ctx,
                  backgroundColor: Colors.transparent,
                  builder: (_) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.surfaceBorder,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Icon(Icons.delete_outline_rounded,
                            color: colors.error, size: 40),
                        const SizedBox(height: 12),
                        Text('Delete Lecture?', style: text.h4),
                        const SizedBox(height: 8),
                        Text(
                          '${lecture.subject} • ${lecture.day} ${lecture.startTime}',
                          style: text.bodySmall.copyWith(
                              color: colors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lecture notifications will also be cancelled.',
                          style: text.caption.copyWith(
                              color: colors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(children: [
                          Expanded(
                            child: BrainUpButton.secondary(
                              label: 'Cancel',
                              onTap: () => Navigator.pop(ctx),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BrainUpButton(
                              label: 'Delete',
                              onTap: () {
                                Navigator.pop(ctx);
                                vm.deleteLecture(lecture.id);
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      color: colors.error, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Delete Lecture',
                    style: text.body.copyWith(color: colors.error),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(BuildContext context) {
    final now = DateTime.now();
    final minutesSinceStart = (now.hour - _startHour) * 60 + now.minute;
    final totalMinutes = (_endHour - _startHour) * 60;
    if (minutesSinceStart < 0 || minutesSinceStart > totalMinutes) {
      return const SizedBox.shrink();
    }
    final x = (minutesSinceStart / 60) * _cellWidth;
    return Positioned(
      left: x - 1,
      top: 0,
      bottom: 0,
      width: 2,
      child: Container(
        width: 2,
        color: context.colors.accent,
      ),
    );
  }
}

class _WeekGridPainter extends CustomPainter {
  final double cellWidth;
  final int cellCount;
  final Color color;

  const _WeekGridPainter({
    required this.cellWidth,
    required this.cellCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    for (int i = 0; i <= cellCount; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_WeekGridPainter old) =>
      old.cellWidth != cellWidth ||
      old.cellCount != cellCount ||
      old.color != color;
}

// ─── ADD TIMETABLE SHEET ─────────────────────────────────────────────────────

class AddTimetableSheet extends StatefulWidget {
  const AddTimetableSheet({super.key});
  @override
  State<AddTimetableSheet> createState() => _AddTimetableSheetState();
}

class _AddTimetableSheetState extends State<AddTimetableSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TimetableViewModel>().clearError();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final vm = context.watch<TimetableViewModel>();
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Add Timetable', style: text.h4),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Manual'),
              Tab(text: 'Image AI'),
              Tab(text: 'Text AI'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _ManualTab(vm: vm),
                _ImageUploadTab(vm: vm),
                _TextPasteTab(vm: vm, ctrl: _textCtrl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualTab extends StatefulWidget {
  final TimetableViewModel vm;
  const _ManualTab({required this.vm});
  @override
  State<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends State<_ManualTab> {
  final _subjectCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  String _day = 'Monday';
  String _startTime = '08:00';
  String _endTime = '09:00';
  String _type = 'lecture';

  final _days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  final _types = ['lecture', 'lab'];

  Future<void> _pickTime(bool isStart) async {
    final parts = (isStart ? _startTime : _endTime).split(':');
    final init = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: context, initialTime: init);
    if (picked != null) {
      final str = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
      setState(() { if (isStart) _startTime = str; else _endTime = str; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrainUpTextField(label: 'Subject', controller: _subjectCtrl, prefixIcon: const Icon(Icons.book_outlined)),
          const SizedBox(height: 12),
          BrainUpTextField(label: 'Teacher', controller: _teacherCtrl, prefixIcon: const Icon(Icons.person_outline)),
          const SizedBox(height: 12),
          BrainUpTextField(label: 'Room', controller: _roomCtrl, prefixIcon: const Icon(Icons.location_on_outlined)),
          const SizedBox(height: 16),
          Text('Day', style: text.label),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _day,
            dropdownColor: colors.surfaceCard,
            style: text.body,
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.surfaceBorder, width: 0.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.surfaceBorder, width: 0.5)),
            ),
            items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => _day = v!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _TimePicker(label: 'Start', time: _startTime, onTap: () => _pickTime(true))),
              const SizedBox(width: 12),
              Expanded(child: _TimePicker(label: 'End', time: _endTime, onTap: () => _pickTime(false))),
            ],
          ),
          const SizedBox(height: 16),
          Text('Type', style: text.label),
          const SizedBox(height: 8),
          Row(
            children: _types.map((t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: BrainUpChip(label: t.toUpperCase(), isSelected: _type == t, onTap: () => setState(() => _type = t)),
            )).toList(),
          ),
          const SizedBox(height: 24),
          BrainUpButton(
            label: 'Add Lecture',
            isLoading: widget.vm.isSaving,
            onTap: () async {
              if (_subjectCtrl.text.trim().isEmpty ||
                  _teacherCtrl.text.trim().isEmpty ||
                  _roomCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please fill all fields'),
                    backgroundColor: colors.error,
                  ),
                );
                return;
              }
              final lec = LectureModel(id: '', day: _day, startTime: _startTime, endTime: _endTime, subject: _subjectCtrl.text.trim(), teacher: _teacherCtrl.text.trim(), room: _roomCtrl.text.trim(), type: _type);
              final nav = Navigator.of(context);
              final ok = await widget.vm.addLectureManually(lec);
              if (ok && mounted) nav.pop();
            },
          ),
        ],
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;
  const _TimePicker({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.surfaceBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: colors.accent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.caption),
                Text(AppDateUtils.timeFromString(time), style: text.body),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageUploadTab extends StatefulWidget {
  final TimetableViewModel vm;
  const _ImageUploadTab({required this.vm});
  @override
  State<_ImageUploadTab> createState() => _ImageUploadTabState();
}

class _ImageUploadTabState extends State<_ImageUploadTab> {
  XFile? _imageFile;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null) {
      widget.vm.clearError();
      setState(() => _imageFile = img);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final vm = widget.vm;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.accent.withOpacity(0.4), width: 1.5, style: BorderStyle.solid),
              ),
              child: _imageFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 48, color: colors.accent),
                        const SizedBox(height: 12),
                        Text('Tap to select timetable image', style: text.bodySmall),
                        const SizedBox(height: 4),
                        Text('PNG, JPG supported', style: text.caption),
                      ],
                    )
                  : Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(_imageFile!.path),
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.surfaceCard.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.edit_rounded,
                                  color: colors.accent, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_imageFile != null) ...[
            BrainUpButton(
              label: 'Extract with AI',
              isLoading: vm.isParsing,
              onTap: vm.isParsing ? null : () async {
                final bytes = await _imageFile!.readAsBytes();
                await vm.parseImageWithGemini(bytes);
              },
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            ),
          ],
          if (vm.parseError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(vm.parseError!, style: text.bodySmall.copyWith(color: colors.error)),
            ),
          ],
          if (vm.parsedLectures.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Review Extracted Lectures', style: text.h4),
            const SizedBox(height: 12),
            ...vm.parsedLectures.asMap().entries.map((e) {
              final idx = e.key;
              final lec = e.value;
              return _EditableParsedCard(
                key: ValueKey(idx),
                lecture: lec,
                onDelete: () => vm.removeParsedLecture(idx),
                onUpdate: (updated) => vm.updateParsedLecture(idx, updated),
              );
            }),
            const SizedBox(height: 12),
            BrainUpButton(
              label: 'Save Timetable',
              isLoading: vm.isSaving,
              onTap: vm.isSaving ? null : () async {
                final nav = Navigator.of(context);
                final ok = await vm.saveParsedLectures();
                if (ok && mounted) nav.pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TextPasteTab extends StatefulWidget {
  final TimetableViewModel vm;
  final TextEditingController ctrl;
  const _TextPasteTab({required this.vm, required this.ctrl});

  @override
  State<_TextPasteTab> createState() => _TextPasteTabState();
}

class _TextPasteTabState extends State<_TextPasteTab> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final vm = widget.vm;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          BrainUpTextField(
            label: 'Paste your timetable text here...',
            controller: widget.ctrl,
            maxLines: 8,
          ),
          const SizedBox(height: 16),
          BrainUpButton(
            label: 'Parse with AI',
            isLoading: vm.isParsing,
            onTap: vm.isParsing ? null : () => vm.parseTextWithGemini(widget.ctrl.text.trim()),
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          ),
          if (vm.parsedLectures.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('${vm.parsedLectures.length} lectures extracted',
                style: text.bodySmall.copyWith(color: colors.success)),
            const SizedBox(height: 12),
            ...vm.parsedLectures.asMap().entries.map((e) {
              final idx = e.key;
              final lec = e.value;
              return _EditableParsedCard(
                key: ValueKey(idx),
                lecture: lec,
                onDelete: () => vm.removeParsedLecture(idx),
                onUpdate: (updated) => vm.updateParsedLecture(idx, updated),
              );
            }),
            const SizedBox(height: 12),
            BrainUpButton(
              label: 'Save Timetable',
              isLoading: vm.isSaving,
              onTap: vm.isSaving
                  ? null
                  : () async {
                      final nav = Navigator.of(context);
                      final ok = await vm.saveParsedLectures();
                      if (ok && mounted) nav.pop();
                    },
            ),
          ],
        ],
      ),
    );
  }
}

class _EditableParsedCard extends StatefulWidget {
  final LectureModel lecture;
  final VoidCallback onDelete;
  final ValueChanged<LectureModel> onUpdate;

  const _EditableParsedCard({
    super.key,
    required this.lecture,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_EditableParsedCard> createState() => _EditableParsedCardState();
}

class _EditableParsedCardState extends State<_EditableParsedCard> {
  bool _editing = false;
  late TextEditingController _subjectCtrl;
  late TextEditingController _teacherCtrl;
  late TextEditingController _roomCtrl;
  late String _day;
  late String _startTime;
  late String _endTime;
  late String _type;

  final _days = ['Monday','Tuesday','Wednesday',
    'Thursday','Friday','Saturday'];

  String _normalizeDay(String raw) {
    final value = raw.trim().toLowerCase();
    const aliases = <String, String>{
      'm': 'Monday',
      'mo': 'Monday',
      'mon': 'Monday',
      'monday': 'Monday',
      't': 'Tuesday',
      'tu': 'Tuesday',
      'tue': 'Tuesday',
      'tues': 'Tuesday',
      'tuesday': 'Tuesday',
      'w': 'Wednesday',
      'we': 'Wednesday',
      'wed': 'Wednesday',
      'wednesday': 'Wednesday',
      'th': 'Thursday',
      'thu': 'Thursday',
      'thur': 'Thursday',
      'thurs': 'Thursday',
      'thursday': 'Thursday',
      'f': 'Friday',
      'fr': 'Friday',
      'fri': 'Friday',
      'friday': 'Friday',
      'sa': 'Saturday',
      'sat': 'Saturday',
      'saturday': 'Saturday',
    };
    return aliases[value] ?? 'Monday';
  }

  @override
  void initState() {
    super.initState();
    _subjectCtrl = TextEditingController(text: widget.lecture.subject);
    _teacherCtrl = TextEditingController(text: widget.lecture.teacher);
    _roomCtrl = TextEditingController(text: widget.lecture.room);
    _day = _normalizeDay(widget.lecture.day);
    _startTime = widget.lecture.startTime;
    _endTime = widget.lecture.endTime;
    _type = widget.lecture.type;
  }

  @override
  void didUpdateWidget(covariant _EditableParsedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lecture != widget.lecture) {
      _subjectCtrl.text = widget.lecture.subject;
      _teacherCtrl.text = widget.lecture.teacher;
      _roomCtrl.text = widget.lecture.room;
      _day = _normalizeDay(widget.lecture.day);
      _startTime = widget.lecture.startTime;
      _endTime = widget.lecture.endTime;
      _type = widget.lecture.type;
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _teacherCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onUpdate(widget.lecture.copyWith(
      subject: _subjectCtrl.text.trim(),
      teacher: _teacherCtrl.text.trim(),
      room: _roomCtrl.text.trim(),
      day: _day,
      startTime: _startTime,
      endTime: _endTime,
      type: _type,
    ));
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrainUpCard(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _editing ? _buildEditForm(context) : _buildReadView(context),
        ),
      ),
    );
  }

  Widget _buildReadView(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final color = AppColors.subjectColor(widget.lecture.subject);
    return Row(children: [
      Container(width: 3, height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          )),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.lecture.subject, style: text.h5),
          const SizedBox(height: 2),
          Text(
            '${widget.lecture.day} · ${widget.lecture.startTime}–${widget.lecture.endTime} · ${widget.lecture.room}',
            style: text.caption,
          ),
          Text(widget.lecture.teacher,
              style: text.caption.copyWith(color: colors.textMuted)),
        ],
      )),
      IconButton(
        icon: Icon(Icons.edit_outlined,
            color: colors.accent, size: 18),
        onPressed: () => setState(() => _editing = true),
      ),
      IconButton(
        icon: Icon(Icons.delete_outline,
            color: colors.error, size: 18),
        onPressed: widget.onDelete,
      ),
    ]);
  }

  Widget _buildEditForm(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final selectedDay = _days.contains(_day) ? _day : _days.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Edit Entry',
              style: text.label.copyWith(color: colors.accent)),
          const Spacer(),
          TextButton(onPressed: _save,
              child: Text('Save',
                  style: TextStyle(color: colors.accent,
                      fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => setState(() => _editing = false),
              child: Text('Cancel',
                  style: TextStyle(color: colors.textSecondary))),
        ]),
        BrainUpTextField(label: 'Subject', controller: _subjectCtrl),
        const SizedBox(height: 8),
        BrainUpTextField(label: 'Teacher', controller: _teacherCtrl),
        const SizedBox(height: 8),
        BrainUpTextField(label: 'Room', controller: _roomCtrl),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedDay,
          dropdownColor: colors.surfaceCard,
          style: text.body,
          decoration: InputDecoration(
            filled: true, fillColor: colors.surfaceElevated,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: colors.surfaceBorder, width: 0.5)),
          ),
          items: _days.map((d) => DropdownMenuItem(
              value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => _day = v ?? _days.first),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _TimePicker(
              label: 'Start', time: _startTime,
              onTap: () async {
                final p = _startTime.split(':');
                final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                        hour: int.parse(p[0]),
                        minute: int.parse(p[1])));
                if (t != null) {
                  setState(() =>
                    _startTime =
                        '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}');
                }
              })),
          const SizedBox(width: 8),
          Expanded(child: _TimePicker(
              label: 'End', time: _endTime,
              onTap: () async {
                final p = _endTime.split(':');
                final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                        hour: int.parse(p[0]),
                        minute: int.parse(p[1])));
                if (t != null) {
                  setState(() =>
                    _endTime =
                        '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}');
                }
              })),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          ...['lecture', 'lab'].map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: BrainUpChip(
              label: t.toUpperCase(),
              isSelected: _type == t,
              onTap: () => setState(() => _type = t),
            ),
          )),
        ]),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── NOW / NEXT BANNER ───────────────────────────────────────────────────────

class _NowNextBanner extends StatelessWidget {
  final TimetableViewModel vm;
  const _NowNextBanner({required this.vm});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = vm.currentLecture;
    final next = vm.nextLectureToday;
    if (current == null && next == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          if (current != null)
            _BannerCard(
              label: 'NOW',
              labelColor: colors.error,
              lecture: current,
              isActive: true,
            ),
          if (current != null && next != null) const SizedBox(height: 8),
          if (next != null)
            _BannerCard(
              label: 'NEXT',
              labelColor: colors.accent,
              lecture: next,
              isActive: false,
            ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String label;
  final Color labelColor;
  final LectureModel lecture;
  final bool isActive;

  const _BannerCard({
    required this.label,
    required this.labelColor,
    required this.lecture,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final color = AppColors.subjectColor(lecture.subject);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            colors.surfaceCard,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? labelColor.withValues(alpha: 0.5)
              : colors.surfaceBorder,
          width: isActive ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: labelColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                  letterSpacing: 1.2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lecture.subject,
                    style: text.h5.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.location_on_outlined,
                      size: 11, color: colors.textMuted),
                  const SizedBox(width: 3),
                  Text(lecture.room, style: text.caption),
                  const SizedBox(width: 8),
                  Icon(Icons.person_outline,
                      size: 11, color: colors.textMuted),
                  const SizedBox(width: 3),
                  Expanded(
                      child: Text(lecture.teacher,
                          style: text.caption,
                          overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(lecture.startTime,
                  style: text.label
                      .copyWith(color: color, fontSize: 13)),
              Text(lecture.formattedDuration,
                  style: text.caption),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Detail Chip ─────────────────────────────────────────────────────────────

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.surfaceBorder, width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: colors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: text.caption),
      ]),
    );
  }
}

// ─── Notification Setting Row ─────────────────────────────────────────────────

class _NotifSettingRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String prefKey;
  final Color color;
  final Future<void> Function(bool)? onChanged;

  const _NotifSettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.prefKey,
    required this.color,
    this.onChanged,
  });

  @override
  State<_NotifSettingRow> createState() => _NotifSettingRowState();
}

class _NotifSettingRowState extends State<_NotifSettingRow> {
  bool _val = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _val = prefs.getBool(widget.prefKey) ?? true);
    }
  }

  Future<void> _toggle(bool v) async {
    setState(() { _val = v; _loading = true; });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.prefKey, v);
    if (widget.onChanged != null) await widget.onChanged!(v);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(widget.icon, color: widget.color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: text.body.copyWith(fontWeight: FontWeight.w600)),
            Text(widget.subtitle, style: text.caption),
          ],
        ),
      ),
      if (_loading)
        SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2,
              color: colors.accent),
        )
      else
        Switch(
          value: _val,
          activeColor: colors.accent,
          onChanged: _toggle,
        ),
    ]);
  }
}
