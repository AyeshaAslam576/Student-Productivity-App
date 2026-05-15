import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  CollectionReference get _attRef =>
      _db.collection('users').doc(_uid).collection('attendance');

  Future<List<AttendanceModel>> fetchAttendance() async {
    final snap = await _attRef.get();
    return snap.docs
        .map((d) => AttendanceModel.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertAttendance(AttendanceModel model) async {
    await _attRef.doc(model.id).set(model.toMap(), SetOptions(merge: true));
  }

  Future<void> addRecord(
      String subjectId, AttendanceRecord record) async {
    await _attRef.doc(subjectId).collection('records').add(record.toMap());
  }

  /// Resolves [subjectName] to an attendance row (creates one if missing),
  /// then records [status] (`present` / `absent`). Used from notification actions.
  Future<bool> markAttendanceBySubjectName(
      String subjectName, String status) async {
    final name = subjectName.trim();
    if (name.isEmpty) return false;

    final snap = await _attRef.get();
    String? subjectId;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final existing = (data['subjectName'] as String?)?.trim() ?? '';
      if (existing.toLowerCase() == name.toLowerCase()) {
        subjectId = doc.id;
        break;
      }
    }
    subjectId ??= await createSubjectAttendance(name);
    await markAttendance(subjectId, status);
    return true;
  }

  Future<void> markAttendance(
      String subjectId, String status) async {
    final doc = await _attRef.doc(subjectId).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final total = (data['totalClasses'] ?? 0) + 1;
    final present = (data['present'] ?? 0) + (status == 'present' ? 1 : 0);
    final absent = (data['absent'] ?? 0) + (status == 'absent' ? 1 : 0);
    await _attRef.doc(subjectId).update({
      'totalClasses': total,
      'present': present,
      'absent': absent,
      'lastMarkedDate': DateTime.now().toIso8601String().split('T').first,
    });
    await addRecord(
      subjectId,
      AttendanceRecord(
        id: '',
        date: DateTime.now(),
        subjectId: subjectId,
        subjectName: data['subjectName'] as String? ?? '',
        status: status,
      ),
    );
  }

  Future<String> createSubjectAttendance(String subjectName) async {
    final ref = await _attRef.add({
      'subjectName': subjectName,
      'totalClasses': 0,
      'present': 0,
      'absent': 0,
    });
    return ref.id;
  }

  Future<void> deleteSubjectAttendance(String subjectId) async {
    await _attRef.doc(subjectId).delete();
  }
}
