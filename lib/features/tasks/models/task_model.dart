import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { critical, high, medium, low }

enum TaskStatus { pending, completed, overdue }

enum TaskType { assignment, quiz, project, homework, exam, lab, presentation, other }

class SubTask {
  final String id;
  final String title;
  bool isCompleted;

  SubTask({required this.id, required this.title, this.isCompleted = false});

  Map<String, dynamic> toMap() =>
      {'id': id, 'title': title, 'isCompleted': isCompleted};

  factory SubTask.fromMap(Map<String, dynamic> m) => SubTask(
        id: m['id'] as String,
        title: m['title'] as String,
        isCompleted: m['isCompleted'] as bool? ?? false,
      );
}

class TaskModel {
  final String id;
  final String userId;
  final String title;
  final String subject;
  final TaskType type;
  final TaskPriority priority;
  final DateTime dueDate;
  final TaskStatus status;
  final String? description;
  final DateTime createdAt;
  final List<SubTask> subtasks;
  final bool hasReminder;
  final DateTime? reminderTime;
  final int? estimatedMinutes;
  final int notificationId;
  final DateTime? completedAt;

  const TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.subject,
    required this.type,
    required this.priority,
    required this.dueDate,
    required this.status,
    this.description,
    required this.createdAt,
    this.subtasks = const [],
    this.hasReminder = false,
    this.reminderTime,
    this.estimatedMinutes,
    this.notificationId = 0,
    this.completedAt,
  });

  factory TaskModel.fromMap(String id, Map<String, dynamic> map) {
    return TaskModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      type: TaskType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TaskType.other,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TaskStatus.pending,
      ),
      description: map['description'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      subtasks: (map['subtasks'] as List<dynamic>? ?? [])
          .map((s) => SubTask.fromMap(s as Map<String, dynamic>))
          .toList(),
      hasReminder: map['hasReminder'] as bool? ?? false,
      reminderTime: (map['reminderTime'] as Timestamp?)?.toDate(),
      estimatedMinutes: map['estimatedMinutes'] as int?,
      notificationId: map['notificationId'] as int? ?? 0,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'subject': subject,
        'type': type.name,
        'priority': priority.name,
        'dueDate': Timestamp.fromDate(dueDate),
        'status': status.name,
        'description': description,
        'createdAt': Timestamp.fromDate(createdAt),
        'subtasks': subtasks.map((s) => s.toMap()).toList(),
        'hasReminder': hasReminder,
        'reminderTime':
            reminderTime != null ? Timestamp.fromDate(reminderTime!) : null,
        'estimatedMinutes': estimatedMinutes,
        'notificationId': notificationId,
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };

  TaskModel copyWith({
    String? userId,
    String? title,
    String? subject,
    TaskType? type,
    TaskPriority? priority,
    DateTime? dueDate,
    TaskStatus? status,
    String? description,
    List<SubTask>? subtasks,
    bool? hasReminder,
    DateTime? reminderTime,
    int? estimatedMinutes,
    int? notificationId,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt,
      subtasks: subtasks ?? this.subtasks,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderTime: reminderTime ?? this.reminderTime,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      notificationId: notificationId ?? this.notificationId,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // ─── Computed ─────────────────────────────────────────────────────────────
  bool get isOverdue =>
      dueDate.isBefore(DateTime.now()) && status != TaskStatus.completed;

  bool get isCompleted => status == TaskStatus.completed;

  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  bool get isDueTomorrow {
    final t = DateTime.now().add(const Duration(days: 1));
    return dueDate.year == t.year &&
        dueDate.month == t.month &&
        dueDate.day == t.day;
  }

  int get subtaskCompletedCount => subtasks.where((s) => s.isCompleted).length;

  double get subtaskProgress =>
      subtasks.isEmpty ? 0 : subtaskCompletedCount / subtasks.length;
}
