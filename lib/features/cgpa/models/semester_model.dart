import 'package:cloud_firestore/cloud_firestore.dart';
import 'subject_grade_model.dart';

class SemesterModel {
  final String id;
  final String name;
  final int year;
  final String session; // Fall / Spring / Summer
  final double gpa;
  final int totalCredits;
  final DateTime createdAt;
  final List<SubjectGradeModel> subjects;

  const SemesterModel({
    required this.id,
    required this.name,
    required this.year,
    required this.session,
    required this.gpa,
    required this.totalCredits,
    required this.createdAt,
    this.subjects = const [],
  });

  factory SemesterModel.fromMap(String id, Map<String, dynamic> map) {
    return SemesterModel(
      id: id,
      name: map['name'] ?? '',
      year: map['year'] ?? DateTime.now().year,
      session: map['session'] ?? 'Fall',
      gpa: (map['gpa'] ?? 0.0).toDouble(),
      totalCredits: map['totalCredits'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'year': year,
        'session': session,
        'gpa': gpa,
        'totalCredits': totalCredits,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static double calculateGpa(List<SubjectGradeModel> subjects) {
    if (subjects.isEmpty) return 0.0;
    final totalQP = subjects.fold<double>(0, (s, e) => s + e.qualityPoints);
    final totalCH = subjects.fold<int>(0, (s, e) => s + e.creditHours);
    if (totalCH == 0) return 0.0;
    return double.parse((totalQP / totalCH).toStringAsFixed(2));
  }

  SemesterModel withSubjects(List<SubjectGradeModel> subs) {
    return SemesterModel(
      id: id,
      name: name,
      year: year,
      session: session,
      gpa: SemesterModel.calculateGpa(subs),
      totalCredits: subs.fold(0, (s, e) => s + e.creditHours),
      createdAt: createdAt,
      subjects: subs,
    );
  }
}
