import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/semester_model.dart';
import '../models/subject_grade_model.dart';

class CgpaRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  CollectionReference get _semRef =>
      _db.collection('users').doc(_uid).collection('semesters');

  Future<List<SemesterModel>> fetchSemesters() async {
    final snap = await _semRef.orderBy('createdAt').get();
    final semesters = <SemesterModel>[];
    for (final doc in snap.docs) {
      final sem = SemesterModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      final subjects = await fetchSubjects(doc.id);
      semesters.add(sem.withSubjects(subjects));
    }
    return semesters;
  }

  Stream<List<SemesterModel>> watchSemesters() {
    return _semRef.orderBy('createdAt').snapshots().asyncMap(
      (snap) async {
        final semesters = <SemesterModel>[];
        for (final doc in snap.docs) {
          final sem = SemesterModel.fromMap(
            doc.id,
            doc.data() as Map<String, dynamic>,
          );
          final subjects = await fetchSubjects(doc.id);
          semesters.add(sem.withSubjects(subjects));
        }
        return semesters;
      },
    );
  }

  Future<List<SubjectGradeModel>> fetchSubjects(String semesterId) async {
    final snap = await _semRef.doc(semesterId).collection('subjects').get();
    return snap.docs
        .map((d) => SubjectGradeModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<String> addSemester(SemesterModel semester) async {
    final ref = await _semRef.add(semester.toMap());
    if (semester.subjects.isNotEmpty) {
      final batch = _db.batch();
      for (final sub in semester.subjects) {
        batch.set(ref.collection('subjects').doc(), sub.toMap());
      }
      await batch.commit();
    }
    return ref.id;
  }

  Future<void> updateSemester(SemesterModel semester) async {
    await _semRef.doc(semester.id).update({
      'gpa': semester.gpa,
      'totalCredits': semester.totalCredits,
    });
  }

  Future<void> deleteSemester(String semesterId) async {
    final subSnap = await _semRef.doc(semesterId).collection('subjects').get();
    final batch = _db.batch();
    for (final doc in subSnap.docs) batch.delete(doc.reference);
    batch.delete(_semRef.doc(semesterId));
    await batch.commit();
  }

  Future<String> addSubject(String semesterId, SubjectGradeModel subject) async {
    final ref = await _semRef.doc(semesterId).collection('subjects').add(subject.toMap());
    return ref.id;
  }

  Future<void> deleteSubject(String semesterId, String subjectId) async {
    await _semRef.doc(semesterId).collection('subjects').doc(subjectId).delete();
  }

  Future<void> saveUserMeta(Map<String, dynamic> data) async {
    await _db.collection('users').doc(_uid).set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getUserMeta() async {
    final doc = await _db.collection('users').doc(_uid).get();
    return doc.data() ?? {};
  }
}
