import 'package:cloud_firestore/cloud_firestore.dart';

class LectureModel {
  final String id;
  final String day;
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String subject;
  final String teacher;
  final String room;
  final String type; // 'lecture' | 'lab'
  final int notificationId15min;
  final int notificationIdStart;
  final bool notificationsEnabled;

  const LectureModel({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.type,
    this.notificationId15min = 0,
    this.notificationIdStart = 0,
    this.notificationsEnabled = true,
  });

  factory LectureModel.fromMap(String id, Map<String, dynamic> map) {
    return LectureModel(
      id: id,
      day: map['day'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      subject: map['subject'] ?? '',
      teacher: map['teacher'] ?? '',
      room: map['room'] ?? '',
      type: map['type'] ?? 'lecture',
      notificationId15min: map['notificationId15min'] as int? ?? 0,
      notificationIdStart: map['notificationIdStart'] as int? ?? 0,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
    );
  }

  factory LectureModel.fromJson(Map<String, dynamic> json) {
    return LectureModel(
      id: '',
      day: json['day'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      subject: json['subject'] ?? '',
      teacher: json['teacher'] ?? '',
      room: json['room'] ?? '',
      type: json['type'] ?? 'lecture',
      notificationsEnabled: true,
    );
  }

  Map<String, dynamic> toMap() => {
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'subject': subject,
        'teacher': teacher,
        'room': room,
        'type': type,
        'notificationId15min': notificationId15min,
        'notificationIdStart': notificationIdStart,
        'notificationsEnabled': notificationsEnabled,
      };

  LectureModel copyWith({
    String? day,
    String? startTime,
    String? endTime,
    String? subject,
    String? teacher,
    String? room,
    String? type,
    int? notificationId15min,
    int? notificationIdStart,
    bool? notificationsEnabled,
  }) {
    return LectureModel(
      id: id,
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subject: subject ?? this.subject,
      teacher: teacher ?? this.teacher,
      room: room ?? this.room,
      type: type ?? this.type,
      notificationId15min: notificationId15min ?? this.notificationId15min,
      notificationIdStart: notificationIdStart ?? this.notificationIdStart,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  bool get isLab => type.toLowerCase() == 'lab';

  int get startMinutes {
    final parts = startTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  int get endMinutes {
    final parts = endTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  int get durationMinutes => endMinutes - startMinutes;

  String get formattedDuration {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  static int generateNotificationId(
      String day, String startTime, String suffix, [int occurrence = 0]) {
    final str = '$day${startTime}${suffix}_$occurrence';
    return str.hashCode.abs() % 2000000000;
  }
}

class TimetableModel {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final List<LectureModel> lectures;

  const TimetableModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.lectures = const [],
  });

  factory TimetableModel.fromMap(String id, Map<String, dynamic> map) {
    return TimetableModel(
      id: id,
      name: map['name'] ?? '',
      isActive: map['isActive'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
