import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';

class TaskViewModel extends ChangeNotifier {
  final TaskRepository _repo;

  TaskViewModel(this._repo) {
    _listenToTasks();
  }

  List<TaskModel> _tasks = [];
  List<String> _timetableSubjects = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String _filter = 'All';
  String? _subjectFilter;
  String _sortOrder = 'Due Date (Earliest)';
  StreamSubscription<List<TaskModel>>? _sub;

  List<TaskModel> get allTasks => _tasks;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String get filter => _filter;
  String? get subjectFilter => _subjectFilter;
  String get sortOrder => _sortOrder;
  String get currentUserId => _repo.currentUserId;

  // ─── New computed properties ───────────────────────────────────────────────
  int get dueTodayCount =>
      _tasks.where((t) => t.isDueToday && !t.isCompleted).length;

  int get overdueCount => _tasks.where((t) => t.isOverdue).length;

  int get pendingCount =>
      _tasks.where((t) => t.status == TaskStatus.pending).length;

  int get completedThisWeek {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _tasks
        .where((t) =>
            t.isCompleted &&
            t.completedAt != null &&
            t.completedAt!.isAfter(weekAgo))
        .length;
  }

  List<TaskModel> get upcomingTasks {
    final list = _tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list.take(5).toList();
  }

  void loadSubjectsFromTimetable(List<String> subjects) {
    _timetableSubjects = subjects;
    notifyListeners();
  }

  // ─── Existing filters & grouping (unchanged) ───────────────────────────────
  List<String> get subjects {
    final fromTasks =
        _tasks.map((t) => t.subject).where((s) => s.isNotEmpty).toSet();
    return {..._timetableSubjects, ...fromTasks}.toList()..sort();
  }

  List<TaskModel> get filteredTasks {
    var list = List<TaskModel>.from(_tasks);
    if (_subjectFilter != null) {
      list = list.where((t) => t.subject == _subjectFilter).toList();
    }
    final now = DateTime.now();
    switch (_filter) {
      case 'Today':
        list = list.where((t) => t.isDueToday).toList();
        break;
      case 'This Week':
        list = list.where((t) {
          final diff = t.dueDate.difference(now).inDays;
          return diff >= 0 && diff <= 7;
        }).toList();
        break;
      case 'Overdue':
        list = list.where((t) => t.isOverdue).toList();
        break;
      case 'Completed':
        list = list.where((t) => t.isCompleted).toList();
        break;
    }
    switch (_sortOrder) {
      case 'Due Date (Earliest)':
        list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case 'Due Date (Latest)':
        list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
        break;
      case 'Priority (High→Low)':
        const rank = {
          TaskPriority.critical: 0,
          TaskPriority.high: 1,
          TaskPriority.medium: 2,
          TaskPriority.low: 3,
        };
        list.sort((a, b) =>
            (rank[a.priority] ?? 99).compareTo(rank[b.priority] ?? 99));
        break;
      case 'Subject A→Z':
        list.sort((a, b) => a.subject.compareTo(b.subject));
        break;
    }
    return list;
  }

  Map<String, List<TaskModel>> get groupedTasks {
    final tasks = filteredTasks;
    final map = <String, List<TaskModel>>{};
    for (final t in tasks) {
      map.putIfAbsent(_groupKey(t), () => []).add(t);
    }
    return map;
  }

  String _groupKey(TaskModel task) {
    if (task.isCompleted) return 'COMPLETED';
    if (task.isOverdue) return 'OVERDUE';
    if (task.isDueToday) return 'TODAY';
    final diff = task.dueDate.difference(DateTime.now()).inDays;
    if (diff == 1) return 'TOMORROW';
    if (diff <= 7) return 'THIS WEEK';
    return 'LATER';
  }

  static const _groupOrder = [
    'OVERDUE', 'TODAY', 'TOMORROW', 'THIS WEEK', 'LATER', 'COMPLETED'
  ];

  List<String> get sortedGroupKeys => groupedTasks.keys.toList()
    ..sort((a, b) => _groupOrder.indexOf(a).compareTo(_groupOrder.indexOf(b)));

  // ─── Stream ────────────────────────────────────────────────────────────────
  void _listenToTasks() {
    _isLoading = true;
    _sub?.cancel();
    _sub = _repo.tasksStream().listen(
      (tasks) {
        _tasks = tasks;
        _isLoading = false;
        _error = null;
        notifyListeners();
        unawaited(rescheduleAllPendingReminders());
      },
      onError: (e) async {
        await Future.delayed(const Duration(seconds: 2));
        if (!_isLoading) {
          _error = _friendlyError(e);
          notifyListeners();
        }
      },
    );
  }

  /// Keep for retry / BrainUpErrorState callback compatibility.
  Future<void> loadTasks() async => _listenToTasks();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _friendlyError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('network')) return 'Check your internet connection';
    if (msg.contains('permission')) return 'Permission denied. Please sign in again.';
    return 'Something went wrong. Please try again.';
  }

  // ─── Actions ───────────────────────────────────────────────────────────────
  Future<bool> addTask(TaskModel task) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _repo.addTask(task);
      _error = null;
      if (task.hasReminder && task.dueDate.isAfter(DateTime.now())) {
        await NotificationService.ensurePermissions();
        await NotificationService.scheduleTaskReminder(
          id: task.notificationId,
          taskTitle: task.title,
          subjectName: task.subject,
          dueDate: task.dueDate,
          priority: task.priority.name,
          customReminderTime: task.reminderTime,
        );
      }
      Future.microtask(() {
        _isSaving = false;
        notifyListeners();
      });
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Re-schedules pending notifications for all tasks still in the future.
  /// Safe to call repeatedly — scheduling the same id is idempotent.
  Future<void> rescheduleAllPendingReminders() async {
    final now = DateTime.now();
    final pending = _tasks.where(
      (t) => !t.isCompleted && t.hasReminder && t.dueDate.isAfter(now),
    );
    if (pending.isEmpty) return;
    await NotificationService.ensurePermissions();
    for (final task in pending) {
      await NotificationService.cancelTaskReminders(task.notificationId);
      await NotificationService.scheduleTaskReminder(
        id: task.notificationId,
        taskTitle: task.title,
        subjectName: task.subject,
        dueDate: task.dueDate,
        priority: task.priority.name,
        customReminderTime: task.reminderTime,
      );
    }
  }

  Future<bool> completeTask(String taskId) async {
    try {
      _error = null;
      await _repo.completeTask(taskId);
      final task = _tasks.firstWhere((t) => t.id == taskId,
          orElse: () => _tasks.first);
      await NotificationService.cancelTaskReminders(task.notificationId);
      final idx = _tasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        _tasks[idx] = _tasks[idx].copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleTaskCompletion(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return false;
    final task = _tasks[idx];
    if (task.isCompleted) {
      try {
        _error = null;
        await _repo.uncompleteTask(taskId);
        _tasks[idx] = _tasks[idx].copyWith(
          status: TaskStatus.pending,
          completedAt: null,
        );
        notifyListeners();
        return true;
      } catch (e) {
        _error = _friendlyError(e);
        notifyListeners();
        return false;
      }
    } else {
      return completeTask(taskId);
    }
  }

  Future<bool> updateTask(TaskModel task) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.updateTask(task);
      await NotificationService.cancelTaskReminders(task.notificationId);
      if (!task.isCompleted &&
          task.hasReminder &&
          task.dueDate.isAfter(DateTime.now())) {
        await NotificationService.ensurePermissions();
        await NotificationService.scheduleTaskReminder(
          id: task.notificationId,
          taskTitle: task.title,
          subjectName: task.subject,
          dueDate: task.dueDate,
          priority: task.priority.name,
          customReminderTime: task.reminderTime,
        );
      }
      Future.microtask(() {
        _isSaving = false;
        notifyListeners();
      });
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    try {
      _error = null;
      final task = _tasks.firstWhere((t) => t.id == taskId,
          orElse: () => _tasks.first);
      await NotificationService.cancelTaskReminders(task.notificationId);
      await _repo.deleteTask(taskId);
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleSubtask(
      String taskId, String subtaskId, bool value) async {
    try {
      await _repo.toggleSubtask(taskId, subtaskId, value);
      final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
      if (taskIdx != -1) {
        final subtasks = List<SubTask>.from(_tasks[taskIdx].subtasks);
        final sIdx = subtasks.indexWhere((s) => s.id == subtaskId);
        if (sIdx != -1) subtasks[sIdx].isCompleted = value;
        _tasks[taskIdx] = _tasks[taskIdx].copyWith(subtasks: subtasks);
        notifyListeners();
      }
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  void setFilter(String f) {
    _filter = f;
    notifyListeners();
  }

  void setSortOrder(String order) {
    _sortOrder = order;
    notifyListeners();
  }

  void clearAllFilters() {
    _filter = 'All';
    _subjectFilter = null;
    notifyListeners();
  }

  void setSubjectFilter(String? s) {
    _subjectFilter = s;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
