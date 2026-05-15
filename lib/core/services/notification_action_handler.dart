import 'dart:async';
import 'dart:convert';

import 'package:brainup/core/router/app_router.dart';
import 'package:brainup/features/attendance/repositories/attendance_repository.dart';
import 'package:brainup/features/attendance/viewmodels/attendance_viewmodel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:brainup/firebase_options.dart';

/// Android background / terminated isolate — notification taps & actions.
@pragma('vm:entry-point')
void onLectureAttendanceNotificationBackground(NotificationResponse response) {
  unawaited(dispatchLocalNotificationResponse(response, isBackgroundIsolate: true));
}

/// Handles lecture-attendance notifications in foreground; also entry for background isolate.
Future<void> dispatchLocalNotificationResponse(
  NotificationResponse response, {
  bool isBackgroundIsolate = false,
}) async {
  final raw = response.payload;
  if (raw == null || raw.isEmpty) return;

  Map<String, dynamic> data;
  try {
    data = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return;
  }
  if (data['t'] != 'lecture_end') return;

  final action = response.actionId;

  if (action != 'att_present' && action != 'att_absent') {
    // Notification body tap — open Attendance (foreground only).
    if (isBackgroundIsolate) return;
    final ctx = brainupRootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ctx.push('/attendance');
    }
    return;
  }

  final subject = (data['sub'] as String?)?.trim() ?? '';
  if (subject.isEmpty) return;

  final status = action == 'att_present' ? 'present' : 'absent';

  if (isBackgroundIsolate) {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (FirebaseAuth.instance.currentUser == null) return;

  final repo = AttendanceRepository();
  await repo.markAttendanceBySubjectName(subject, status);

  if (isBackgroundIsolate) return;

  final ctx = brainupRootNavigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(ctx);
  try {
    await ctx.read<AttendanceViewModel>().loadAttendance();
  } catch (_) {}
  if (!ctx.mounted) return;
  messenger?.showSnackBar(
      SnackBar(
        content: Text(
          status == 'present'
              ? 'Marked $subject as present'
              : 'Marked $subject as absent',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
