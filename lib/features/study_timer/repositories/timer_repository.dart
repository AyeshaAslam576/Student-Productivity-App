import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/study_session_model.dart';
import '../models/timer_phase.dart';

class TimerRepository {
  final FirebaseFirestore _db;
  final String userId;

  TimerRepository({
    required FirebaseFirestore db,
    required this.userId,
  }) : _db = db;

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _db.collection('users').doc(userId).collection('study_sessions');

  Future<void> saveSession(StudySessionModel session) async {
    await _sessionsRef.add(session.toMap());
  }

  Stream<List<StudySessionModel>> watchRecentSessions({int limit = 20}) {
    return _sessionsRef
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => StudySessionModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<Map<String, int>> getWeeklyMinutes() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    // Single-field range query — no composite index needed.
    // Phase is filtered client-side to avoid a compound query.
    final snap = await _sessionsRef
        .where('completedAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .get();

    final result = <String, int>{};
    for (final doc in snap.docs) {
      final session = StudySessionModel.fromMap(doc.id, doc.data());
      if (session.phase != TimerPhase.focus) continue;
      final day = '${session.completedAt.weekday}';
      result[day] = (result[day] ?? 0) + (session.durationSeconds ~/ 60);
    }
    return result;
  }

  Future<int> getStreakDays() async {
    // Single orderBy — no composite index needed.
    // Phase is filtered client-side to avoid a compound query.
    final snap = await _sessionsRef
        .orderBy('completedAt', descending: true)
        .limit(60)
        .get();

    final activeDays = <String>{};
    for (final doc in snap.docs) {
      final session = StudySessionModel.fromMap(doc.id, doc.data());
      if (session.phase != TimerPhase.focus) continue;
      final key =
          '${session.completedAt.year}-${session.completedAt.month}-${session.completedAt.day}';
      activeDays.add(key);
    }

    int streak = 0;
    DateTime check = DateTime.now();
    while (true) {
      final key = '${check.year}-${check.month}-${check.day}';
      if (activeDays.contains(key)) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}
