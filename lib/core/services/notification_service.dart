import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'notification_plugin.dart';

class NotificationService {
  static final _plugin = flutterLocalNotificationsPlugin;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // LectureNotificationService may set this later; fall back to UTC.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final channel = AndroidNotificationChannel(
      'task_reminders',
      'Task Reminders',
      description: 'Reminders for upcoming tasks and deadlines',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
    );
    await androidPlugin?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Request POST_NOTIFICATIONS on Android 13+ (no-op if already granted).
  static Future<bool> ensurePermissions() async {
    if (!_initialized) await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  static Future<void> scheduleTaskReminder({
    required int id,
    required String taskTitle,
    required String subjectName,
    required DateTime dueDate,
    required String priority,
    DateTime? customReminderTime,
  }) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();

    // User-selected reminder chip (1h / 3h / 1 day before due)
    if (customReminderTime != null && customReminderTime.isAfter(now)) {
      await _scheduleOne(
        id: id + 3,
        title: '🔔 Task reminder',
        body: '$taskTitle ($subjectName)',
        scheduledDate: customReminderTime,
        priority: priority,
      );
    }

    // At due time
    if (dueDate.isAfter(now)) {
      await _scheduleOne(
        id: id,
        title: '📚 $subjectName — Due Now',
        body: '$taskTitle is due!',
        scheduledDate: dueDate,
        priority: priority,
      );
    }

    // 1 hour before
    final oneHourBefore = dueDate.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      await _scheduleOne(
        id: id + 1,
        title: '⏰ Due in 1 hour',
        body: '$taskTitle ($subjectName)',
        scheduledDate: oneHourBefore,
        priority: priority,
      );
    }

    // 24 hours before
    final dayBefore = dueDate.subtract(const Duration(hours: 24));
    if (dayBefore.isAfter(now)) {
      await _scheduleOne(
        id: id + 2,
        title: '📋 Due tomorrow',
        body: '$taskTitle ($subjectName)',
        scheduledDate: dayBefore,
        priority: priority,
      );
    }
  }

  static Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String priority,
  }) async {
    final importance = (priority == 'critical' || priority == 'high')
        ? Importance.max
        : Importance.high;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          importance: importance,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelTaskReminders(int notificationId) async {
    await _plugin.cancel(notificationId);
    await _plugin.cancel(notificationId + 1);
    await _plugin.cancel(notificationId + 2);
    await _plugin.cancel(notificationId + 3);
  }

  static Future<void> cancelAll() async => _plugin.cancelAll();
}
