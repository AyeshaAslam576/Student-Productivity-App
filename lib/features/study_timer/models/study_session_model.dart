import 'package:cloud_firestore/cloud_firestore.dart';
import 'timer_phase.dart';

class StudySessionModel {
  final String id;
  final String subject;
  final int durationSeconds;
  final TimerPhase phase;
  final DateTime completedAt;

  const StudySessionModel({
    required this.id,
    required this.subject,
    required this.durationSeconds,
    required this.phase,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'durationSeconds': durationSeconds,
      'phase': phase.name,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }

  factory StudySessionModel.fromMap(String id, Map<String, dynamic> map) {
    final completedAtRaw = map['completedAt'];
    final completedAt = completedAtRaw is Timestamp
        ? completedAtRaw.toDate()
        : DateTime.tryParse(completedAtRaw?.toString() ?? '') ?? DateTime.now();
    final phaseName = map['phase']?.toString() ?? TimerPhase.focus.name;

    return StudySessionModel(
      id: id,
      subject: (map['subject'] ?? 'General').toString(),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      phase: TimerPhase.values.firstWhere(
        (value) => value.name == phaseName,
        orElse: () => TimerPhase.focus,
      ),
      completedAt: completedAt,
    );
  }

  factory StudySessionModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return StudySessionModel.fromMap(doc.id, doc.data());
  }
}
