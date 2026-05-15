
class SubjectGradeModel {
  final String id;
  final String name;
  final int creditHours;
  final String grade; // A+, A, A-, B+, etc.
  final double gradePoints;
  final double? marks; // percentage

  const SubjectGradeModel({
    required this.id,
    required this.name,
    required this.creditHours,
    required this.grade,
    required this.gradePoints,
    this.marks,
  });

  factory SubjectGradeModel.fromMap(String id, Map<String, dynamic> map) {
    return SubjectGradeModel(
      id: id,
      name: map['name'] ?? '',
      creditHours: map['creditHours'] ?? 3,
      grade: map['grade'] ?? 'B',
      gradePoints: (map['gradePoints'] ?? 3.0).toDouble(),
      marks: map['marks']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'creditHours': creditHours,
        'grade': grade,
        'gradePoints': gradePoints,
        'marks': marks,
      };

  double get qualityPoints => gradePoints * creditHours;

  static double gradePointsFromGrade(String grade) {
    return switch (grade) {
      'A+' => 4.0,
      'A' => 4.0,
      'A-' => 3.7,
      'B+' => 3.3,
      'B' => 3.0,
      'B-' => 2.7,
      'C+' => 2.3,
      'C' => 2.0,
      'C-' => 1.7,
      'D' => 1.0,
      'F' => 0.0,
      _ => 0.0,
    };
  }

  static String gradeFromMarks(double marks) {
    if (marks >= 90) return 'A+';
    if (marks >= 85) return 'A';
    if (marks >= 80) return 'A-';
    if (marks >= 75) return 'B+';
    if (marks >= 70) return 'B';
    if (marks >= 65) return 'B-';
    if (marks >= 60) return 'C+';
    if (marks >= 55) return 'C';
    if (marks >= 50) return 'C-';
    if (marks >= 45) return 'D';
    return 'F';
  }

  static const List<String> allGrades = [
    'A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D', 'F'
  ];
}
