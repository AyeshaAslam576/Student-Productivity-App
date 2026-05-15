import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lecture_model.dart';

class TimetableRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  CollectionReference get _ttRef =>
      _db.collection('users').doc(_uid).collection('timetables');

  Future<String> createTimetable(String name) async {
    final ref = await _ttRef.add({
      'name': name,
      'isActive': true,
      'createdAt': Timestamp.now(),
    });
    return ref.id;
  }

  Future<List<LectureModel>> fetchLectures(String timetableId) async {
    final snap = await _ttRef
        .doc(timetableId)
        .collection('lectures')
        .get();
    return snap.docs
        .map((d) => LectureModel.fromMap(d.id, d.data()))
        .toList();
  }

  Stream<List<LectureModel>> lecturesStream(String timetableId) {
    return _ttRef
        .doc(timetableId)
        .collection('lectures')
        .snapshots()
        .map((s) => s.docs.map((d) => LectureModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> addLectures(String timetableId, List<LectureModel> lectures) async {
    final batch = _db.batch();
    final lectureRef = _ttRef.doc(timetableId).collection('lectures');
    for (final lec in lectures) {
      final ref = lectureRef.doc();
      batch.set(ref, lec.toMap());
    }
    await batch.commit();
  }

  Future<void> addLecture(String timetableId, LectureModel lecture) async {
    await _ttRef.doc(timetableId).collection('lectures').add(lecture.toMap());
  }

  Future<void> updateLecture(String timetableId, LectureModel lecture) async {
    await _ttRef.doc(timetableId).collection('lectures').doc(lecture.id).update(lecture.toMap());
  }

  Future<void> deleteLecture(String timetableId, String lectureId) async {
    await _ttRef.doc(timetableId).collection('lectures').doc(lectureId).delete();
  }

  Future<String?> getActiveTimetableId() async {
    final snap = await _ttRef.where('isActive', isEqualTo: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<void> deleteActiveTimetable() async {
    final id = await getActiveTimetableId();
    if (id == null) return;

    final lectures = await _db
        .collection('users')
        .doc(_uid)
        .collection('timetables')
        .doc(id)
        .collection('lectures')
        .get();

    for (final doc in lectures.docs) {
      await doc.reference.delete();
    }

    await _db
        .collection('users')
        .doc(_uid)
        .collection('timetables')
        .doc(id)
        .delete();
  }
}
