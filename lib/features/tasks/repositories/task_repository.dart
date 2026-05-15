import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';

class TaskRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  String get currentUserId => _auth.currentUser?.uid ?? '';

  CollectionReference get _tasksRef =>
      _db.collection('users').doc(_uid).collection('tasks');

  Stream<List<TaskModel>> tasksStream() {
    return _tasksRef
        .orderBy('dueDate')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TaskModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<List<TaskModel>> fetchTasks() async {
    final snap = await _tasksRef.orderBy('dueDate').get();
    return snap.docs
        .map((d) => TaskModel.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<String> addTask(TaskModel task) async {
    final ref = await _tasksRef.add(task.toMap());
    return ref.id;
  }

  Future<void> updateTask(TaskModel task) async {
    await _tasksRef.doc(task.id).update(task.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
  }

  Future<void> completeTask(String taskId) async {
    await _tasksRef.doc(taskId).update({
      'status': TaskStatus.completed.name,
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> toggleSubtask(
      String taskId, String subtaskId, bool value) async {
    final doc = await _tasksRef.doc(taskId).get();
    final data = doc.data() as Map<String, dynamic>;
    final subtasks = (data['subtasks'] as List<dynamic>? ?? [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    final idx = subtasks.indexWhere((s) => s['id'] == subtaskId);
    if (idx != -1) subtasks[idx]['isCompleted'] = value;
    await _tasksRef.doc(taskId).update({'subtasks': subtasks});
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    await _tasksRef.doc(taskId).update({
      'status': status.name,
      if (status == TaskStatus.completed)
        'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<Map<String, int>> getTaskStats() async {
    final tasks = await fetchTasks();
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return {
      'total': tasks.length,
      'pending': tasks.where((t) => t.status == TaskStatus.pending).length,
      'overdue': tasks.where((t) => t.isOverdue).length,
      'dueToday': tasks.where((t) => t.isDueToday && !t.isCompleted).length,
      'completedThisWeek': tasks
          .where((t) =>
              t.isCompleted &&
              t.completedAt != null &&
              t.completedAt!.isAfter(weekAgo))
          .length,
    };
  }
}
