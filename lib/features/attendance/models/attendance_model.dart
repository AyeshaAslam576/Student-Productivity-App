import 'package:cloud_firestore/cloud_firestore.dart';

enum RiskLevel { safe, warning, danger, detained }

class AttendanceModel {
  final String id;
  final String subjectName;
  final int totalClasses;
  final int present;
  final int absent;
  final int totalSemesterClasses; // estimated total lectures in the semester
  final String? lastMarkedDate; // ISO date string yyyy-MM-dd

  const AttendanceModel({
    required this.id,
    required this.subjectName,
    required this.totalClasses,
    required this.present,
    required this.absent,
    this.totalSemesterClasses = 45, // default: 3 classes/week × 15 weeks
    this.lastMarkedDate,
  });

  // ── Core computed ──────────────────────────────────────────────
  double get percentage =>
      totalClasses == 0 ? 100.0 : (present / totalClasses) * 100;

  bool get isSafe => percentage >= 75;
  bool get isWarning => percentage >= 65 && percentage < 75;
  bool get isCritical => percentage >= 50 && percentage < 65;
  bool get isDetained => percentage < 50;

  RiskLevel get riskLevel {
    if (percentage >= 75) return RiskLevel.safe;
    if (percentage >= 65) return RiskLevel.warning;
    if (percentage >= 50) return RiskLevel.danger;
    return RiskLevel.detained;
  }

  // ── FEATURE 1: How many can I miss? ───────────────────────────
  /// Exact count of lectures student can still miss and stay ≥ 75%
  int get safeToMiss {
    // solve: (present) / (totalClasses + x) >= 0.75
    // x = floor(present/0.75 - totalClasses)
    final canMiss = (present / 0.75 - totalClasses).floor();
    return canMiss.clamp(0, 999);
  }

  /// Lectures needed to climb back to 75%
  int get mustAttendToRecover {
    if (isSafe) return 0;
    // solve: (present + x) / (totalClasses + x) >= 0.75
    for (int x = 1; x <= 200; x++) {
      if ((present + x) / (totalClasses + x) >= 0.75) return x;
    }
    return 999;
  }

  // ── FEATURE 2: Detention Risk Score ──────────────────────────
  /// Remaining lectures left in semester
  int get remainingLectures =>
      (totalSemesterClasses - totalClasses).clamp(0, 999);

  /// Best possible % if student attends ALL remaining lectures
  double get bestCasePercentage {
    if (totalSemesterClasses == 0) return percentage;
    return ((present + remainingLectures) / totalSemesterClasses) * 100;
  }

  /// Can student mathematically still reach 75%?
  bool get canStillRecover => bestCasePercentage >= 75;

  /// Risk score 0–100 (higher = more dangerous)
  double get detentionRiskScore {
    if (isSafe && safeToMiss > 5) return 0;
    if (isDetained && !canStillRecover) return 100;
    if (isDetained) return 85 + (15 * (1 - bestCasePercentage / 75));
    if (isCritical) return 60 + (25 * (75 - percentage) / 25);
    if (isWarning) return 25 + (35 * (75 - percentage) / 10);
    // safe but close
    if (safeToMiss <= 2) return 15;
    return 0;
  }

  // ── FEATURE 3: Smart Leave Planner ───────────────────────────
  /// How many days the student can skip safely given N lectures per skip-day
  int safeSkipDays({int lecturesPerDay = 1}) {
    if (lecturesPerDay == 0) return 0;
    return (safeToMiss / lecturesPerDay).floor();
  }

  // ── Firestore ─────────────────────────────────────────────────
  factory AttendanceModel.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceModel(
      id: id,
      subjectName: map['subjectName'] as String? ?? '',
      totalClasses: map['totalClasses'] as int? ?? 0,
      present: map['present'] as int? ?? 0,
      absent: map['absent'] as int? ?? 0,
      totalSemesterClasses: map['totalSemesterClasses'] as int? ?? 45,
      lastMarkedDate: map['lastMarkedDate'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'subjectName': subjectName,
        'totalClasses': totalClasses,
        'present': present,
        'absent': absent,
        'totalSemesterClasses': totalSemesterClasses,
        'lastMarkedDate': lastMarkedDate,
      };

  AttendanceModel copyWith({
    int? totalClasses,
    int? present,
    int? absent,
    int? totalSemesterClasses,
    String? lastMarkedDate,
  }) => AttendanceModel(
        id: id,
        subjectName: subjectName,
        totalClasses: totalClasses ?? this.totalClasses,
        present: present ?? this.present,
        absent: absent ?? this.absent,
        totalSemesterClasses: totalSemesterClasses ?? this.totalSemesterClasses,
        lastMarkedDate: lastMarkedDate ?? this.lastMarkedDate,
      );
}

// ── Per-lecture attendance log ─────────────────────────────────
class AttendanceRecord {
  final String id;
  final DateTime date;
  final String subjectId;
  final String subjectName;
  final String status; // 'present' | 'absent'
  final String? note;

  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.subjectId,
    required this.subjectName,
    required this.status,
    this.note,
  });

  bool get isPresent => status == 'present';

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) =>
      AttendanceRecord(
        id: id,
        date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        subjectId: map['subjectId'] as String? ?? '',
        subjectName: map['subjectName'] as String? ?? '',
        status: map['status'] as String? ?? 'present',
        note: map['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'subjectId': subjectId,
        'subjectName': subjectName,
        'status': status,
        if (note != null) 'note': note,
      };
}

// ── Sick leave range ───────────────────────────────────────────
class SickLeaveRange {
  final DateTime from;
  final DateTime to;
  final String? reason;
  const SickLeaveRange({required this.from, required this.to, this.reason});
}

// ── Leave plan result ─────────────────────────────────────────
class LeavePlanDay {
  final DateTime date;
  final List<String> subjectsOnDay;
  final bool isSafeToSkip;
  final String reason;
  const LeavePlanDay({
    required this.date,
    required this.subjectsOnDay,
    required this.isSafeToSkip,
    required this.reason,
  });
}
