import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ai_session_model.dart';

class AiSessionRepository {
  final FirebaseFirestore _db;
  final String userId;

  AiSessionRepository({
    required FirebaseFirestore db,
    required this.userId,
  }) : _db = db;

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _db.collection('users').doc(userId).collection('ai_sessions');

  Stream<List<AiSession>> watchRecentSessions({
    int limit = 20,
    SessionType? type,
  }) {
    Query<Map<String, dynamic>> query =
        _sessionsRef.orderBy('lastAccessedAt', descending: true).limit(limit);
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => AiSession.fromMap(doc.data()))
              .toList(),
        );
  }

  Stream<List<AiSession>> watchFavoriteSessions(SessionType type) {
    return _sessionsRef
        .where('type', isEqualTo: type.name)
        .where('isFavorite', isEqualTo: true)
        .orderBy('lastAccessedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AiSession.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<AiSession> saveSession(AiSession session) async {
    final now = DateTime.now();
    final createdAt = session.createdAt;
    final persisted = session.copyWith(
      createdAt: createdAt,
      lastAccessedAt: now,
    );
    await _sessionsRef.doc(session.id).set(persisted.toMap());
    return persisted;
  }

  Future<void> deleteSession(String sessionId) {
    return _sessionsRef.doc(sessionId).delete();
  }

  Future<void> toggleFavorite(String sessionId, bool value) {
    return _sessionsRef.doc(sessionId).update({'isFavorite': value});
  }

  Future<void> updateLastAccessed(String sessionId) {
    return _sessionsRef.doc(sessionId).update({
      'lastAccessedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> renameSession(String sessionId, String newTitle) {
    return _sessionsRef.doc(sessionId).update({'originalInput': newTitle});
  }

  Future<List<AiSession>> searchSessions(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final docs = await _sessionsRef
        .orderBy('lastAccessedAt', descending: true)
        .limit(100)
        .get();
    final sessions = docs.docs.map((d) => AiSession.fromMap(d.data())).toList();
    return sessions
        .where((s) =>
            s.preview.toLowerCase().contains(q) ||
            s.originalInput.toLowerCase().contains(q) ||
            s.output.toLowerCase().contains(q))
        .toList();
  }

  Future<void> clearOldSessions({int olderThanDays = 30}) async {
    final cutoff =
        DateTime.now().subtract(Duration(days: olderThanDays)).toIso8601String();
    final oldDocs =
        await _sessionsRef.where('createdAt', isLessThan: cutoff).get();
    for (final doc in oldDocs.docs) {
      await doc.reference.delete();
    }
  }
}
