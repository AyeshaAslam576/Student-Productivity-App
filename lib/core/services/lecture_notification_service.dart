import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'notification_plugin.dart';
import 'notification_action_handler.dart';
import '../../features/timetable/models/lecture_model.dart';

// ─── Motivational Quotes ─────────────────────────────────────────────────────

class _Quotes {
  static const List<String> preLecture = [
    "The secret of getting ahead is getting started. — Mark Twain",
    "An investment in knowledge pays the best interest. — Benjamin Franklin",
    "Education is the most powerful weapon you can use to change the world. — Nelson Mandela",
    "The more that you read, the more things you will know. — Dr. Seuss",
    "Learning never exhausts the mind. — Leonardo da Vinci",
    "Push yourself, because no one else is going to do it for you.",
    "Great things never come from comfort zones.",
    "Dream it. Believe it. Build it.",
    "Your future is created by what you do today, not tomorrow.",
    "Success is the sum of small efforts repeated day in and day out.",
    "Strive for progress, not perfection.",
    "Believe you can and you're halfway there. — Theodore Roosevelt",
  ];

  static const List<String> lectureStart = [
    "Focus. Every minute in class is an investment in your future. 🎯",
    "This lecture could have the idea that changes everything for you. 💡",
    "Show up fully. Your future self is watching. 🌟",
    "Knowledge is power. You're gaining both right now. ⚡",
    "Sit in the front row of your own life. Be present. 🧠",
    "Every expert was once a student. You're on your way. 🚀",
    "Pay attention. This is where champions are made. 🏆",
    "The classroom is your battlefield. Conquer it! ⚔️",
  ];

  static const List<String> breakTime = [
    "Great work! Take a real break — your brain needs it. ☕",
    "You've earned this. Step away from the screen for a moment. 🌿",
    "Rest is not laziness. It is essential. Recharge! 🔋",
    "Hydrate. Stretch. Breathe. Your next lecture is coming. 💧",
    "A refreshed mind learns better. Enjoy this break! 😌",
    "Even the best athletes rest between rounds. So should you. 🧘",
    "Take a walk. Fresh air clears the mind like nothing else. 🌬️",
    "Your break time is productive time — use it to reset! ⏰",
  ];

  static const List<String> morningDigest = [
    "Good morning! Today is another chance to be great. 🌅",
    "Rise and shine — your schedule is ready and so are you! ☀️",
    "A new day, a new opportunity to learn something amazing. 📚",
    "Today's lectures are stepping stones to your dreams. Let's go! 🎓",
    "The early student gets the knowledge. You've got this! 🦉",
    "Make today count. Your future is built one lecture at a time. 🏗️",
  ];

  static const List<String> lastLectureDone = [
    "That's a wrap! You crushed it today. Be proud. 🎉",
    "All done for today! Rest well — you've earned it. 🌙",
    "Another productive day complete. Tomorrow, even better! 💪",
    "Classes done! Time to review your notes and reward yourself. ✅",
    "You showed up. That's half the battle. Great work today! 🌟",
  ];

  static String getRandom(List<String> list) {
    final copy = List<String>.from(list)..shuffle();
    return copy.first;
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class LectureNotificationService {
  static final _plugin = flutterLocalNotificationsPlugin;
  static bool _initialized = false;

  static const Color _accentColor = Color(0xFF00C2FF);

  // ─── INITIALIZE ────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
          onLectureAttendanceNotificationBackground,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Lecture Alerts (15-min warning)
    final alertChannel = AndroidNotificationChannel(
      'lecture_alerts',
      'Lecture Alerts',
      description: 'Reminders before your lectures start',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
    );
    await androidPlugin?.createNotificationChannel(alertChannel);

    // Lecture Start
    const startChannel = AndroidNotificationChannel(
      'lecture_start',
      'Lecture Starting',
      description: 'Notification when your lecture begins',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin?.createNotificationChannel(startChannel);

    // Break Time
    const breakChannel = AndroidNotificationChannel(
      'break_time',
      'Break Time',
      description: 'Notifications during breaks between lectures',
      importance: Importance.defaultImportance,
      playSound: true,
    );
    await androidPlugin?.createNotificationChannel(breakChannel);

    const endOfDayChannel = AndroidNotificationChannel(
      'end_of_day',
      'End of Day',
      description: 'Notification when all lectures for the day are done',
      importance: Importance.defaultImportance,
      playSound: true,
    );
    await androidPlugin?.createNotificationChannel(endOfDayChannel);

    // Morning Digest
    const morningChannel = AndroidNotificationChannel(
      'morning_digest',
      'Daily Schedule',
      description: "Morning summary of today's schedule",
      importance: Importance.high,
      playSound: true,
    );
    await androidPlugin?.createNotificationChannel(morningChannel);

    // Study Timer (Pomodoro phase-complete notifications)
    const timerChannel = AndroidNotificationChannel(
      'brainup_timer',
      'Study Timer',
      description: 'Notifications when a Pomodoro focus or break phase ends',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin?.createNotificationChannel(timerChannel);

    // Task Reminders (due-date alerts)
    const taskChannel = AndroidNotificationChannel(
      'task_reminders',
      'Task Reminders',
      description: 'Reminders for upcoming tasks and deadlines',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin?.createNotificationChannel(taskChannel);

    // Lecture ended — quick attendance actions (Android inline actions)
    const lectureEndChannel = AndroidNotificationChannel(
      'lecture_end',
      'Class Finished',
      description: 'When a lecture ends — mark attendance with one tap',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin?.createNotificationChannel(lectureEndChannel);

    _initialized = true;
  }

  static void _onNotificationTap(NotificationResponse response) {
    unawaited(dispatchLocalNotificationResponse(response));
  }

  // ─── PERMISSIONS ───────────────────────────────────────────────────────────

  static Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final result = await android?.requestNotificationsPermission();
    return result ?? false;
  }

  // ─── SCHEDULE LECTURE ──────────────────────────────────────────────────────

  static Future<void> scheduleLectureNotifications(LectureModel lecture) async {
    if (!_initialized) await initialize();
    if (!lecture.notificationsEnabled) return;

    final occurrences = _getNextOccurrences(lecture, count: 4);

    for (int i = 0; i < occurrences.length; i++) {
      final lecTime = occurrences[i];
      final fifteenBefore = lecTime.subtract(const Duration(minutes: 15));
      final now = DateTime.now();

      if (fifteenBefore.isAfter(now)) {
        await _scheduleExact(
          id: lecture.notificationId15min + i,
          title: '⏰ Lecture in 15 minutes',
          body: '${lecture.subject} • ${lecture.room} • ${lecture.teacher}',
          subtitle: _Quotes.getRandom(_Quotes.preLecture),
          scheduledTime: fifteenBefore,
          channelId: 'lecture_alerts',
          channelName: 'Lecture Alerts',
          payload: lecture.id,
          bigText: '📍 Room: ${lecture.room}\n'
              '👨‍🏫 ${lecture.teacher}\n'
              '⏱ ${lecture.startTime} – ${lecture.endTime} (${lecture.formattedDuration})\n\n'
              '"${_Quotes.getRandom(_Quotes.preLecture)}"',
        );
      }

      if (lecTime.isAfter(now)) {
        await _scheduleExact(
          id: lecture.notificationIdStart + i,
          title: '${lecture.isLab ? '🔬 Lab' : '📖 Lecture'} Starting Now!',
          body: '${lecture.subject} • ${lecture.room}',
          subtitle: '${lecture.teacher} | ${lecture.startTime} – ${lecture.endTime}',
          scheduledTime: lecTime,
          channelId: 'lecture_start',
          channelName: 'Lecture Starting',
          payload: lecture.id,
          bigText: '📚 ${lecture.subject}\n'
              '📍 Room: ${lecture.room}\n'
              '👨‍🏫 ${lecture.teacher}\n'
              '⏱ ${lecture.startTime} – ${lecture.endTime}\n\n'
              '💬 "${_Quotes.getRandom(_Quotes.lectureStart)}"',
        );
      }
    }
  }

  // ─── BREAK NOTIFICATION ────────────────────────────────────────────────────

  static Future<void> scheduleBreakNotification({
    required LectureModel endedLecture,
    required LectureModel nextLecture,
    required int notificationId,
  }) async {
    if (!_initialized) await initialize();

    final occurrences = _getNextOccurrences(endedLecture, count: 4);
    final endParts = endedLecture.endTime.split(':');
    final nextParts = nextLecture.startTime.split(':');
    final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final nextMin = int.parse(nextParts[0]) * 60 + int.parse(nextParts[1]);
    final breakDuration = nextMin - endMin;
    final breakText = breakDuration >= 60
        ? '${breakDuration ~/ 60}h ${breakDuration % 60}min break'
        : '${breakDuration}min break';

    for (int i = 0; i < occurrences.length; i++) {
      final breakStart = occurrences[i].add(const Duration(minutes: 5));
      if (breakStart.isAfter(DateTime.now())) {
        await _scheduleExact(
          id: notificationId + i,
          title: '☕ $breakText',
          body: 'Next: ${nextLecture.subject} at ${nextLecture.startTime}',
          subtitle: _Quotes.getRandom(_Quotes.breakTime),
          scheduledTime: breakStart,
          channelId: 'break_time',
          channelName: 'Break Time',
          payload: '',
          bigText: '⏰ Next lecture at ${nextLecture.startTime}\n'
              '📍 ${nextLecture.room} | ${nextLecture.teacher}\n\n'
              '💬 "${_Quotes.getRandom(_Quotes.breakTime)}"',
        );
      }
    }
  }

  // ─── MORNING DIGEST ────────────────────────────────────────────────────────

  static Future<void> scheduleMorningDigest({
    required List<LectureModel> allLectures,
    required int notificationId,
  }) async {
    if (!_initialized) await initialize();
    assert(tz.local.name.isNotEmpty, 'Timezone must be set before scheduling');

    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];

    for (int dayOffset = 0; dayOffset < 28; dayOffset++) {
      final date = DateTime.now().add(Duration(days: dayOffset));
      final scheduled8AM =
          DateTime(date.year, date.month, date.day, 8, 0);
      if (scheduled8AM.isBefore(DateTime.now())) continue;

      final dayName = weekdays[date.weekday - 1];
      final dayLectures = allLectures
          .where((l) => l.day
              .toLowerCase()
              .startsWith(dayName.toLowerCase().substring(0, 3)))
          .toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

      if (dayLectures.isEmpty) continue;

      final summary = dayLectures
          .map((l) => '• ${l.startTime}–${l.endTime} ${l.subject} (${l.room})')
          .join('\n');
      final first = dayLectures.first;

      await _scheduleExact(
        id: notificationId + dayOffset,
        title:
            '📅 ${dayLectures.length} class${dayLectures.length > 1 ? 'es' : ''} today',
        body:
            'First: ${first.subject} at ${first.startTime} in ${first.room}',
        subtitle: _Quotes.getRandom(_Quotes.morningDigest),
        scheduledTime: scheduled8AM,
        channelId: 'morning_digest',
        channelName: 'Daily Schedule',
        payload: 'morning_digest',
        bigText: '🌅 Good morning! Your schedule today:\n\n'
            '$summary\n\n'
            '💬 "${_Quotes.getRandom(_Quotes.morningDigest)}"',
      );
    }
  }

  // ─── END OF DAY ────────────────────────────────────────────────────────────

  static Future<void> scheduleEndOfDayNotification({
    required LectureModel lastLecture,
    required int notificationId,
  }) async {
    if (!_initialized) await initialize();

    final occurrences = _getNextOccurrences(lastLecture, count: 4);
    for (int i = 0; i < occurrences.length; i++) {
      final endTime = occurrences[i].add(const Duration(minutes: 2));
      if (endTime.isAfter(DateTime.now())) {
        final quote = _Quotes.getRandom(_Quotes.lastLectureDone);
        await _scheduleExact(
          id: notificationId + i,
          title: '🎉 All lectures done for today!',
          body: quote,
          subtitle: 'Time to review your notes and recharge.',
          scheduledTime: endTime,
          channelId: 'end_of_day',
          channelName: 'End of Day',
          payload: '',
          bigText: '$quote\n\n'
              "📝 Review your notes from today's lectures.\n"
              '💤 Rest well — tomorrow is another opportunity to grow!',
        );
      }
    }
  }

  // ─── CANCEL ────────────────────────────────────────────────────────────────

  static Future<void> cancelLectureNotifications(LectureModel lecture) async {
    for (int i = 0; i < 4; i++) {
      await _plugin.cancel(lecture.notificationId15min + i);
      await _plugin.cancel(lecture.notificationIdStart + i);
      await _plugin.cancel(
        LectureModel.generateNotificationId(
            lecture.day, lecture.endTime, 'end', i),
      );
    }
  }

  static Future<void> cancelAllNotifications() async => _plugin.cancelAll();

  // ─── RESCHEDULE ALL ────────────────────────────────────────────────────────

  static Future<void> rescheduleAllForTimetable(
      List<LectureModel> lectures) async {
    if (!_initialized) await initialize();
    await cancelAllNotifications();

    final prefs = await SharedPreferences.getInstance();
    final show15min = prefs.getBool('notif_15min') ?? true;
    final showStart = prefs.getBool('notif_start') ?? true;
    final showBreak = prefs.getBool('notif_break') ?? true;
    final showMorning = prefs.getBool('notif_morning') ?? true;
    final showLectureEnd = prefs.getBool('notif_lecture_end') ?? true;

    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
    ];

    for (final day in weekdays) {
      final dayLectures = lectures
          .where((l) => l.day
              .toLowerCase()
              .startsWith(day.toLowerCase().substring(0, 3)))
          .toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

      if (dayLectures.isEmpty) continue;

      for (int i = 0; i < dayLectures.length; i++) {
        final lec = dayLectures[i];
        if (!lec.notificationsEnabled) continue;

        if (show15min) {
          await _scheduleOne15min(lec, i);
        }

        if (showStart) {
          await _scheduleOneStart(lec, i);
        }

        if (showLectureEnd) {
          await _scheduleOneLectureEnd(lec);
        }

        if (showBreak && i < dayLectures.length - 1) {
          final nextLec = dayLectures[i + 1];
          if (nextLec.startMinutes - lec.endMinutes > 5) {
            await scheduleBreakNotification(
              endedLecture: lec,
              nextLecture: nextLec,
              notificationId:
                  LectureModel.generateNotificationId(day, lec.endTime, 'break', i),
            );
          }
        }

        if (i == dayLectures.length - 1) {
          await scheduleEndOfDayNotification(
            lastLecture: lec,
            notificationId:
                LectureModel.generateNotificationId(day, lec.endTime, 'done', i),
          );
        }
      }
    }

    if (showMorning) {
      try {
        await scheduleMorningDigest(
          allLectures: lectures,
          notificationId: 99990,
        );
      } catch (e) {
        debugPrint(
          '[LectureNotificationService] Morning digest scheduling failed: $e',
        );
      }
    }
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  static Future<void> _scheduleOne15min(LectureModel lecture, int i) async {
    final occurrences = _getNextOccurrences(lecture, count: 4);
    final now = DateTime.now();
    for (int weekIndex = 0; weekIndex < occurrences.length; weekIndex++) {
      final lecTime = occurrences[weekIndex];
      final fifteenBefore = lecTime.subtract(const Duration(minutes: 15));
      if (!fifteenBefore.isAfter(now)) continue;

      await _scheduleExact(
        id: lecture.notificationId15min + weekIndex,
        title: '⏰ Lecture in 15 minutes',
        body: '${lecture.subject} • ${lecture.room} • ${lecture.teacher}',
        subtitle: _Quotes.getRandom(_Quotes.preLecture),
        scheduledTime: fifteenBefore,
        channelId: 'lecture_alerts',
        channelName: 'Lecture Alerts',
        payload: lecture.id,
        bigText: '📍 Room: ${lecture.room}\n'
            '👨‍🏫 ${lecture.teacher}\n'
            '⏱ ${lecture.startTime} – ${lecture.endTime} (${lecture.formattedDuration})\n\n'
            '"${_Quotes.getRandom(_Quotes.preLecture)}"',
      );
    }
  }

  static Future<void> _scheduleOneStart(LectureModel lecture, int i) async {
    final occurrences = _getNextOccurrences(lecture, count: 4);
    final now = DateTime.now();
    for (int weekIndex = 0; weekIndex < occurrences.length; weekIndex++) {
      final lecTime = occurrences[weekIndex];
      if (!lecTime.isAfter(now)) continue;

      await _scheduleExact(
        id: lecture.notificationIdStart + weekIndex,
        title: '${lecture.isLab ? '🔬 Lab' : '📖 Lecture'} Starting Now!',
        body: '${lecture.subject} • ${lecture.room}',
        subtitle: '${lecture.teacher} | ${lecture.startTime} – ${lecture.endTime}',
        scheduledTime: lecTime,
        channelId: 'lecture_start',
        channelName: 'Lecture Starting',
        payload: lecture.id,
        bigText: '📚 ${lecture.subject}\n'
            '📍 Room: ${lecture.room}\n'
            '👨‍🏫 ${lecture.teacher}\n'
            '⏱ ${lecture.startTime} – ${lecture.endTime}\n\n'
            '💬 "${_Quotes.getRandom(_Quotes.lectureStart)}"',
      );
    }
  }

  static String _lectureEndPayload(LectureModel lecture) => jsonEncode({
        't': 'lecture_end',
        'sub': lecture.subject,
        'lid': lecture.id,
      });

  /// When the scheduled end time of a class is reached — tap actions to log attendance.
  static Future<void> _scheduleOneLectureEnd(LectureModel lecture) async {
    final occurrences = _getNextOccurrencesAtEndTime(lecture, count: 4);
    final now = DateTime.now();
    for (int weekIndex = 0; weekIndex < occurrences.length; weekIndex++) {
      final endMoment = occurrences[weekIndex];
      if (!endMoment.isAfter(now)) continue;

      final id = LectureModel.generateNotificationId(
          lecture.day, lecture.endTime, 'end', weekIndex);

      await _scheduleExact(
        id: id,
        title: '🏫 Class finished',
        body: '${lecture.subject} • ${lecture.room} — mark attendance',
        subtitle: '${lecture.startTime}–${lecture.endTime} · ${lecture.day}',
        scheduledTime: endMoment,
        channelId: 'lecture_end',
        channelName: 'Class Finished',
        payload: _lectureEndPayload(lecture),
        bigText: '📚 ${lecture.subject}\n'
            '📍 ${lecture.room}\n'
            '👨‍🏫 ${lecture.teacher}\n\n'
            'Class just ended. Use Present / Absent below (Android), or open BrainUp → Attendance.',
        androidActions: const [
          AndroidNotificationAction(
            'att_present',
            'Present',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'att_absent',
            'Absent',
            showsUserInterface: true,
          ),
        ],
      );
    }
  }

  static List<DateTime> _getNextOccurrences(LectureModel lecture,
      {int count = 4}) {
    const weekdayMap = {
      'mon': 1, 'monday': 1,
      'tue': 2, 'tuesday': 2,
      'wed': 3, 'wednesday': 3,
      'thu': 4, 'thursday': 4,
      'fri': 5, 'friday': 5,
      'sat': 6, 'saturday': 6,
      'sun': 7, 'sunday': 7,
    };

    final dayKey = lecture.day.toLowerCase().trim();
    int? targetWeekday;
    for (final entry in weekdayMap.entries) {
      if (dayKey.startsWith(entry.key)) {
        targetWeekday = entry.value;
        break;
      }
    }
    if (targetWeekday == null) return [];

    final timeParts = lecture.startTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final occurrences = <DateTime>[];
    var current = DateTime.now();

    while (occurrences.length < count) {
      if (current.weekday == targetWeekday) {
        final candidate = DateTime(
            current.year, current.month, current.day, hour, minute);
        if (candidate.isAfter(DateTime.now())) {
          occurrences.add(candidate);
        }
      }
      current = current.add(const Duration(days: 1));
    }

    return occurrences;
  }

  /// Same weekday as the lecture, but at [LectureModel.endTime] instead of start.
  static List<DateTime> _getNextOccurrencesAtEndTime(LectureModel lecture,
      {int count = 4}) {
    const weekdayMap = {
      'mon': 1,
      'monday': 1,
      'tue': 2,
      'tuesday': 2,
      'wed': 3,
      'wednesday': 3,
      'thu': 4,
      'thursday': 4,
      'fri': 5,
      'friday': 5,
      'sat': 6,
      'saturday': 6,
      'sun': 7,
      'sunday': 7,
    };

    final dayKey = lecture.day.toLowerCase().trim();
    int? targetWeekday;
    for (final entry in weekdayMap.entries) {
      if (dayKey.startsWith(entry.key)) {
        targetWeekday = entry.value;
        break;
      }
    }
    if (targetWeekday == null) return [];

    final timeParts = lecture.endTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final occurrences = <DateTime>[];
    var current = DateTime.now();

    while (occurrences.length < count) {
      if (current.weekday == targetWeekday) {
        final candidate = DateTime(
            current.year, current.month, current.day, hour, minute);
        if (candidate.isAfter(DateTime.now())) {
          occurrences.add(candidate);
        }
      }
      current = current.add(const Duration(days: 1));
    }

    return occurrences;
  }

  static Future<void> _scheduleExact({
    required int id,
    required String title,
    required String body,
    required String subtitle,
    required DateTime scheduledTime,
    required String channelId,
    required String channelName,
    required String payload,
    required String bigText,
    List<AndroidNotificationAction>? androidActions,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            bigText,
            contentTitle: title,
            summaryText: subtitle,
          ),
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: _accentColor,
          enableLights: true,
          ledColor: _accentColor,
          ledOnMs: 1000,
          ledOffMs: 500,
          actions: androidActions,
        ),
        iOS: DarwinNotificationDetails(
          subtitle: subtitle,
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: channelId,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }
}
