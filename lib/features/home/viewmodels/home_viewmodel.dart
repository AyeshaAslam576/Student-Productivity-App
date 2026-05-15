import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/repositories/task_repository.dart';
import '../../attendance/models/attendance_model.dart';
import '../../attendance/repositories/attendance_repository.dart';

class HomeViewModel extends ChangeNotifier {
  final TaskRepository _taskRepo;
  final AttendanceRepository _attRepo;

  HomeViewModel(this._taskRepo, this._attRepo) {
    loadAll();
  }

  StreamSubscription<List<TaskModel>>? _tasksSub;

  List<TaskModel> _tasks = [];
  List<AttendanceModel> _attendance = [];
  bool _isLoading = true;
  String? _error;
  int _studyStreakDays = 0;
  double _studyHoursToday = 0;

  List<bool> _weekStudiedDays = List.filled(7, false);

  List<TaskModel> get tasks => _tasks;
  List<TaskModel> get dueSoonTasks => _tasks
      .where((t) {
        if (t.isCompleted) return false;
        final diff = t.dueDate.difference(DateTime.now()).inDays;
        return diff >= 0 && diff <= 7;
      })
      .take(3)
      .toList();
  List<TaskModel> get dueTodayTasks =>
      _tasks.where((t) => t.isDueToday && !t.isCompleted).toList();
  List<AttendanceModel> get attendance => _attendance;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get studyStreakDays => _studyStreakDays;
  double get studyHoursToday => _studyHoursToday;
  List<bool> get weekStudiedDays => List.unmodifiable(_weekStudiedDays);

  double get overallAttendance {
    if (_attendance.isEmpty) return 0;
    final total = _attendance.fold<int>(0, (s, a) => s + a.totalClasses);
    final present = _attendance.fold<int>(0, (s, a) => s + a.present);
    if (total == 0) return 0;
    return (present / total) * 100;
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    super.dispose();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (_tasksSub == null) {
        _tasksSub = _taskRepo.tasksStream().listen((tasks) {
          _tasks = tasks;
          _isLoading = false;
          notifyListeners();
        }, onError: (e) {
          _error = e.toString();
          notifyListeners();
        });
      }
      _attendance = await _attRepo.fetchAttendance();

      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final key = 'study_minutes_${today.year}_${today.month}_${today.day}';
      final minutes = prefs.getInt(key) ?? 0;
      _studyHoursToday = minutes / 60.0;
      _calculateStreak(prefs, today);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  void _calculateStreak(SharedPreferences prefs, DateTime today) {
    // ── Consecutive-day streak ──────────────────────────────────────────────
    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final day = today.subtract(Duration(days: i));
      final k = 'study_minutes_${day.year}_${day.month}_${day.day}';
      if ((prefs.getInt(k) ?? 0) > 0) {
        streak++;
      } else {
        break;
      }
    }
    _studyStreakDays = streak;

    // ── Which days of the current week were studied (Mon=0 … Sun=6) ─────────
    final monday = today.subtract(Duration(days: today.weekday - 1));
    _weekStudiedDays = List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final k = 'study_minutes_${day.year}_${day.month}_${day.day}';
      return (prefs.getInt(k) ?? 0) > 0;
    });
  }

  /// Lightweight refresh — only re-reads SharedPreferences study stats.
  /// Called by TimerViewModel after each completed focus session.
  Future<void> refreshStudyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key = 'study_minutes_${today.year}_${today.month}_${today.day}';
    _studyHoursToday = (prefs.getInt(key) ?? 0) / 60.0;
    _calculateStreak(prefs, today);
    notifyListeners();
  }

  Future<void> refresh() => loadAll();
}
