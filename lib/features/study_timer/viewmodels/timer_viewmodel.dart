import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/services/groq_service.dart';
import '../models/study_session_model.dart';
import '../models/timer_phase.dart';
import '../repositories/timer_repository.dart';

class TimerViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final FlutterLocalNotificationsPlugin _notifications;
  TimerRepository _repository;
  final AudioPlayer _ambientPlayer = AudioPlayer();
  // Dedicated single-shot player for end-of-phase chime so it never collides
  // with the looping ambient track.
  final AudioPlayer _completionPlayer = AudioPlayer();

  /// Called after every completed focus session so HomeViewModel can refresh
  /// its streak and study-hours stats without a full reload.
  VoidCallback? onSessionSaved;

  // ── Background reliability ─────────────────────────────────────────────────
  static const int _timerNotifId = 9999;
  static const _prefPhaseEndMs = 'timer_phase_end_ms';
  static const _prefPhaseInFlight = 'timer_phase_in_flight';
  static const _prefPhaseName = 'timer_phase_name';
  int? _phaseEndMs;

  TimerViewModel(
    this._notifications,
    this._repository,
  ) {
    WidgetsBinding.instance.addObserver(this);
    _bindSessionStream();
    loadStats();
    _loadCompletionSoundPref();
    _recoverFromPrefs();
  }

  // Settings
  int focusDuration = 25 * 60;
  int shortBreakDuration = 5 * 60;
  int longBreakDuration = 15 * 60;

  TimerPhase _phase = TimerPhase.focus;
  int _timeLeft = 25 * 60;
  bool _isRunning = false;
  int _sessionsCompleted = 0;
  String _selectedSubject = 'General';
  Timer? _timer;
  StreamSubscription<List<StudySessionModel>>? _sessionsSub;
  Stream<List<StudySessionModel>> _sessionHistoryStream = const Stream.empty();
  List<StudySessionModel> _sessionHistory = [];
  List<String> _availableSubjects = ['General', 'Other'];
  Map<String, int> _weeklyMinutes = {};
  int _streakDays = 0;
  bool _isLoadingStats = false;
  String? _statsError;
  String? _aiCoachMessage;
  bool _isLoadingCoach = false;

  final List<Map<String, String>> ambientSounds = const [
    {'label': 'None',        'icon': '🔇', 'url': ''},
    {'label': 'Lofi',        'icon': '🎵', 'url': 'assets/sounds/lofi.mp3'},
    {'label': 'Rain',        'icon': '🌧️', 'url': 'assets/sounds/rain.mp3'},
    {'label': 'White Noise', 'icon': '🌊', 'url': 'assets/sounds/white_noise.mp3'},
    {'label': 'Cafe',        'icon': '☕', 'url': 'assets/sounds/cafe.mp3'},
  ];
  int _selectedSound = 0;

  // Phase-end completion chime. Plays once when a focus / break phase ends.
  // The user drops the actual MP3 files into assets/sounds/ — empty string =
  // silent.
  final List<Map<String, String>> completionSounds = const [
    {'label': 'Silent', 'icon': '🔕', 'url': ''},
    {'label': 'Chime',  'icon': '🛎️', 'url': 'assets/sounds/complete_chime.mp3'},
    {'label': 'Ding',   'icon': '🔔', 'url': 'assets/sounds/complete_ding.mp3'},
  ];
  int _selectedCompletionSound = 1; // default: Chime
  static const _completionSoundPrefKey = 'timer_completion_sound';

  TimerPhase get phase => _phase;
  int get timeLeft => _timeLeft;
  bool get isRunning => _isRunning;
  int get sessionsCompleted => _sessionsCompleted;
  String get selectedSubject => _selectedSubject;
  List<StudySessionModel> get sessionHistory =>
      List.unmodifiable(_sessionHistory);
  Stream<List<StudySessionModel>> get sessionHistoryStream =>
      _sessionHistoryStream;
  List<String> get availableSubjects => List.unmodifiable(_availableSubjects);
  Map<String, int> get weeklyMinutes => _weeklyMinutes;
  int get streakDays => _streakDays;
  bool get isLoadingStats => _isLoadingStats;
  String? get statsError => _statsError;
  String? get aiCoachMessage => _aiCoachMessage;
  bool get isLoadingCoach => _isLoadingCoach;
  int get selectedSound => _selectedSound;
  int get selectedCompletionSound => _selectedCompletionSound;

  double get progress {
    final total = _phaseDuration;
    if (total == 0) return 0;
    return 1.0 - (_timeLeft / total);
  }

  int get _phaseDuration => switch (_phase) {
        TimerPhase.focus => focusDuration,
        TimerPhase.shortBreak => shortBreakDuration,
        TimerPhase.longBreak => longBreakDuration,
      };

  String get phaseLabel => switch (_phase) {
        TimerPhase.focus => 'FOCUS',
        TimerPhase.shortBreak => 'SHORT BREAK',
        TimerPhase.longBreak => 'LONG BREAK',
      };

  String get timeDisplay {
    final m = _timeLeft ~/ 60;
    final s = _timeLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _resumeAmbientSoundIfNeeded();
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // Schedule a backup notification so the user is alerted even if Android
    // suspends the Dart isolate while the app is backgrounded.
    unawaited(_schedulePhaseEndNotification());
  }

  void pause() {
    _isRunning = false;
    _timer?.cancel();
    _ambientPlayer.stop();
    unawaited(_cancelPhaseEndNotification());
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _isRunning = false;
    _timeLeft = _phaseDuration;
    _ambientPlayer.stop();
    unawaited(_cancelPhaseEndNotification());
    notifyListeners();
  }

  void skip() {
    _timer?.cancel();
    _isRunning = false;
    _ambientPlayer.stop();
    unawaited(_cancelPhaseEndNotification());
    _advance();
  }

  Future<void> _onPhaseComplete({bool fromRecovery = false}) async {
    // Stop the looping ambient first so the completion chime can be heard
    // cleanly. (Previously the ambient track kept playing past the phase end.)
    try {
      await _ambientPlayer.stop();
    } catch (_) {}
    if (!fromRecovery) {
      HapticFeedback.heavyImpact();
      // Play the one-shot completion chime (if not Silent). Skipped on
      // recovery from a killed-app state because the scheduled notification
      // already alerted the user.
      unawaited(_playCompletionSound());
    }
    // The scheduled phase-end notification has already fired (in background)
    // or is about to fire (in foreground). Either way, clear the persisted
    // phase markers.
    unawaited(_clearPersistedPhase());
    if (_phase == TimerPhase.focus) {
      _sessionsCompleted++;
      try {
        await _repository.saveSession(
          StudySessionModel(
            id: '',
            subject: _selectedSubject,
            durationSeconds: focusDuration,
            phase: TimerPhase.focus,
            completedAt: DateTime.now(),
          ),
        );
        final sessionMinutes = focusDuration ~/ 60;
        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now();
        final key = 'study_minutes_${today.year}_${today.month}_${today.day}';
        final existing = prefs.getInt(key) ?? 0;
        await prefs.setInt(key, existing + sessionMinutes);
        onSessionSaved?.call();
      } catch (_) {}
      await loadStats();
      await generateCoachMessage();
    }
    _advance();
  }

  void _advance() {
    if (_phase == TimerPhase.focus) {
      if (_sessionsCompleted % 4 == 0) {
        _phase = TimerPhase.longBreak;
        _timeLeft = longBreakDuration;
      } else {
        _phase = TimerPhase.shortBreak;
        _timeLeft = shortBreakDuration;
      }
    } else {
      _phase = TimerPhase.focus;
      _timeLeft = focusDuration;
    }
    notifyListeners();
  }

  void setSubject(String subject) {
    _selectedSubject = subject;
    notifyListeners();
  }

  void loadSubjectsFromTimetable(List<String> timetableSubjects) {
    final unique = {'General', ...timetableSubjects, 'Other'}.toList();
    _availableSubjects = unique;
    if (!_availableSubjects.contains(_selectedSubject)) {
      _selectedSubject = _availableSubjects.first;
    }
    notifyListeners();
  }

  void updateSettings({int? focus, int? shortBreak, int? longBreak}) {
    if (focus != null) focusDuration = focus * 60;
    if (shortBreak != null) shortBreakDuration = shortBreak * 60;
    if (longBreak != null) longBreakDuration = longBreak * 60;
    reset();
  }

  Future<void> loadStats() async {
    _isLoadingStats = true;
    _statsError = null;
    notifyListeners();
    try {
      _weeklyMinutes = await _repository.getWeeklyMinutes();
      _streakDays = await _repository.getStreakDays();
    } catch (_) {
      _weeklyMinutes = {};
      _streakDays = 0;
      _statsError = 'Could not load your weekly stats right now.';
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  Future<void> generateCoachMessage() async {
    _isLoadingCoach = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final totalTodayMin = _sessionHistory
          .where(
            (session) =>
                session.phase == TimerPhase.focus &&
                session.completedAt.year == now.year &&
                session.completedAt.month == now.month &&
                session.completedAt.day == now.day,
          )
          .fold<int>(0, (sum, session) => sum + session.durationSeconds ~/ 60);

      final prompt = '''
A university student just completed a ${focusDuration ~/ 60}-minute focus session on $_selectedSubject.
They have studied $totalTodayMin minutes today total across ${_sessionHistory.length} sessions.
Their study streak is $_streakDays days.

Give a SHORT 1-2 sentence coaching message that:
1. Acknowledges their current effort specifically
2. Gives ONE concrete suggestion for the next session
Be warm, specific, and encouraging. Return plain text only, no JSON.
      ''';

      _aiCoachMessage = await GroqService.chat(
        model: 'llama-3.3-70b-versatile',
        messages: [{'role': 'user', 'content': prompt}],
        maxTokens: 100,
        temperature: 0.8,
      );
    } catch (_) {
      _aiCoachMessage =
          'Great session! Take a proper break - your brain needs rest to consolidate what you just learned.';
    } finally {
      _isLoadingCoach = false;
      notifyListeners();
    }
  }

  Future<void> selectCompletionSound(int index) async {
    if (index < 0 || index >= completionSounds.length) return;
    _selectedCompletionSound = index;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_completionSoundPrefKey, index);
    } catch (_) {}
  }

  Future<void> _loadCompletionSoundPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_completionSoundPrefKey);
      if (stored != null &&
          stored >= 0 &&
          stored < completionSounds.length) {
        _selectedCompletionSound = stored;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _playCompletionSound() async {
    if (_selectedCompletionSound == 0) return;
    final url = completionSounds[_selectedCompletionSound]['url'] ?? '';
    if (url.isEmpty) return;
    try {
      await _completionPlayer.stop();
      await _completionPlayer.setAsset(url);
      await _completionPlayer.setLoopMode(LoopMode.off);
      await _completionPlayer.play();
    } catch (_) {
      // Asset missing (e.g. user hasn't dropped MP3 in yet) — fail silently.
    }
  }

  Future<void> selectSound(int index) async {
    _selectedSound = index;
    notifyListeners();

    final url = ambientSounds[index]['url'] ?? '';
    try {
      await _ambientPlayer.stop();
      if (index == 0 || url.isEmpty) return;

      // All sounds are local assets now — always works, no internet needed
      await _ambientPlayer.setAsset(url);
      await _ambientPlayer.setLoopMode(LoopMode.all);
      if (_isRunning) await _ambientPlayer.play();
      notifyListeners();
    } catch (e) {
      // Asset not found — reset to None
      _selectedSound = 0;
      await _ambientPlayer.stop();
      notifyListeners();
    }
  }

  void updateDependencies({
    required TimerRepository repository,
  }) {
    final repoChanged = repository.userId != _repository.userId;
    _repository = repository;
    if (repoChanged) {
      _bindSessionStream();
      loadStats();
    }
  }

  int get totalWeeklyMinutes =>
      _weeklyMinutes.values.fold<int>(0, (sum, min) => sum + min);

  String get mostStudiedSubjectThisWeek {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final minutesBySubject = <String, int>{};
    for (final session in _sessionHistory) {
      if (session.phase != TimerPhase.focus ||
          session.completedAt.isBefore(cutoff)) {
        continue;
      }
      minutesBySubject[session.subject] =
          (minutesBySubject[session.subject] ?? 0) +
              (session.durationSeconds ~/ 60);
    }
    if (minutesBySubject.isEmpty) return 'No sessions yet';
    final top = minutesBySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return top.first.key;
  }

  /// Schedules a single end-of-phase notification at `now + _timeLeft`. This
  /// is what makes the alert reliable even if the Dart isolate is suspended
  /// in the background, because `flutter_local_notifications` uses Android's
  /// exact alarm scheduler under the hood.
  Future<void> _schedulePhaseEndNotification() async {
    try {
      await _cancelPhaseEndNotification();
      final fireAt = DateTime.now().add(Duration(seconds: _timeLeft));
      _phaseEndMs = fireAt.millisecondsSinceEpoch;
      await _persistPhaseEnd(_phaseEndMs!, _phase);

      const androidDetails = AndroidNotificationDetails(
        'brainup_timer',
        'Study Timer',
        channelDescription: 'Pomodoro timer notifications',
        importance: Importance.high,
        priority: Priority.high,
        // NOTE: if the user later drops `complete_chime.mp3` into
        // `android/app/src/main/res/raw/`, replace the next line with
        //   sound: RawResourceAndroidNotificationSound('complete_chime'),
        // For now the channel's default sound is used.
      );
      final title =
          _phase == TimerPhase.focus ? '⏰ Break time!' : '🎯 Focus time!';
      final body = _phase == TimerPhase.focus
          ? 'Great work! Time for a break.'
          : 'Break over. Time to focus!';

      await _notifications.zonedSchedule(
        _timerNotifId,
        title,
        body,
        tz.TZDateTime.from(fireAt, tz.local),
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Scheduling can fail if the user denied exact-alarm permission. The
      // in-app timer still works; we just lose background reliability.
    }
  }

  Future<void> _cancelPhaseEndNotification() async {
    try {
      await _notifications.cancel(_timerNotifId);
    } catch (_) {}
    _phaseEndMs = null;
  }

  Future<void> _persistPhaseEnd(int endMs, TimerPhase phase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefPhaseEndMs, endMs);
      await prefs.setBool(_prefPhaseInFlight, true);
      await prefs.setString(_prefPhaseName, phase.name);
    } catch (_) {}
  }

  Future<void> _clearPersistedPhase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefPhaseEndMs);
      await prefs.remove(_prefPhaseInFlight);
      await prefs.remove(_prefPhaseName);
    } catch (_) {}
  }

  /// On VM construction (which also covers "app was killed and reopened"),
  /// check whether a phase was in flight. If its end time has already passed,
  /// run the post-completion bookkeeping silently (no chime/haptic — the
  /// scheduled notification already fired).
  Future<void> _recoverFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_prefPhaseInFlight) ?? false)) return;
      final endMs = prefs.getInt(_prefPhaseEndMs);
      final phaseName = prefs.getString(_prefPhaseName);
      if (endMs == null) {
        await _clearPersistedPhase();
        return;
      }
      // Restore the active phase first so post-completion bookkeeping
      // (sessionsCompleted++, saveSession, etc.) is tagged to the right phase.
      if (phaseName != null) {
        for (final p in TimerPhase.values) {
          if (p.name == phaseName) {
            _phase = p;
            break;
          }
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= endMs) {
        _timeLeft = 0;
        await _onPhaseComplete(fromRecovery: true);
      } else {
        // Phase still in progress — but the Dart timer isn't running yet
        // (user just reopened the app). Resume countdown.
        _timeLeft = ((endMs - now) / 1000).ceil();
        _phaseEndMs = endMs;
        _isRunning = true;
        notifyListeners();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  /// While the app was backgrounded the Dart `Timer.periodic` was suspended.
  /// On resume, reconcile `_timeLeft` against the real wall clock. If the
  /// phase already elapsed in background, finalize it.
  Future<void> _handleResume() async {
    if (!_isRunning || _phaseEndMs == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= _phaseEndMs!) {
      _timer?.cancel();
      _isRunning = false;
      _timeLeft = 0;
      notifyListeners();
      await _onPhaseComplete(fromRecovery: true);
    } else {
      _timeLeft = ((_phaseEndMs! - now) / 1000).ceil();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _sessionsSub?.cancel();
    _ambientPlayer.dispose();
    _completionPlayer.dispose();
    super.dispose();
  }

  void _tick() {
    if (_timeLeft <= 0) {
      _timer?.cancel();
      _isRunning = false;
      unawaited(_onPhaseComplete());
      return;
    }
    _timeLeft--;
    notifyListeners();
  }

  void _bindSessionStream() {
    _sessionsSub?.cancel();
    _sessionHistoryStream = _repository.watchRecentSessions(limit: 20);
    _sessionsSub = _sessionHistoryStream.listen((sessions) {
      _sessionHistory = sessions;
      notifyListeners();
    });
  }

  Future<void> _resumeAmbientSoundIfNeeded() async {
    if (_selectedSound == 0) return;
    final url = ambientSounds[_selectedSound]['url'] ?? '';
    if (url.isEmpty) return;
    try {
      if (!_ambientPlayer.playing) {
        if (_ambientPlayer.audioSource == null) {
          await _ambientPlayer.setAsset(url);
          await _ambientPlayer.setLoopMode(LoopMode.all);
        }
        await _ambientPlayer.play();
      }
    } catch (_) {
      _selectedSound = 0;
      notifyListeners();
    }
  }
}
