import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/lecture_model.dart';
import '../repositories/timetable_repository.dart';
import '../../../core/services/lecture_notification_service.dart';

class TimetableViewModel extends ChangeNotifier {
  final TimetableRepository _repo;
  final String groqApiKey;

  TimetableViewModel(this._repo, {required this.groqApiKey}) {
    loadTimetable();
  }

  String? _activeTimetableId;
  List<LectureModel> _lectures = [];
  List<LectureModel> _parsedLectures = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isParsing = false;
  String? _error;
  String? _parseError;
  int _selectedTab = 0;

  String? get activeTimetableId => _activeTimetableId;
  List<LectureModel> get lectures => _lectures;
  List<LectureModel> get parsedLectures => _parsedLectures;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isParsing => _isParsing;
  String? get error => _error;
  String? get parseError => _parseError;
  int get selectedTab => _selectedTab;

  List<LectureModel> lecturesForDay(String day) {
    return _lectures
        .where((l) => l.day.toLowerCase().startsWith(day.toLowerCase().substring(0, 3)))
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  List<LectureModel> get todayLectures {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final today = days[DateTime.now().weekday - 1];
    return lecturesForDay(today);
  }

  List<String> get subjects =>
      _lectures.map((l) => l.subject).toSet().toList()..sort();

  LectureModel? get nextLectureToday {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    return todayLectures
        .where((l) => l.startMinutes > nowMinutes)
        .toList()
        .firstOrNull;
  }

  LectureModel? get currentLecture {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    return todayLectures
        .where((l) => l.startMinutes <= nowMinutes && l.endMinutes > nowMinutes)
        .toList()
        .firstOrNull;
  }

  Future<void> loadTimetable() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _activeTimetableId = await _repo.getActiveTimetableId();
      if (_activeTimetableId != null) {
        _lectures = await _repo.fetchLectures(_activeTimetableId!);
        if (_lectures.isNotEmpty) {
          await LectureNotificationService.rescheduleAllForTimetable(_lectures);
        }
      }
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  static const _imagePrompt = '''
You are an expert at reading university timetable images. Analyze the timetable grid carefully.

TIMETABLE STRUCTURE:
- Rows = days of the week (Monday, Tuesday, Wednesday, Thursday, Friday, Saturday)
- Columns = time slots (read the exact times from the top header row)
- Each cell may contain: subject/course code, teacher name, room/lab number
- Cells may be merged horizontally (spanning multiple time slots = longer class)
- Ignore any break columns (Prayer break, Lunch break, etc.)

EXTRACTION RULES:
1. Read ALL time slots from the header row precisely (e.g. 8:00, 8:30, 9:00, 9:30...)
2. For each filled cell, record the START time of its first column and END time of its last column
3. If a subject appears in the same time slot on multiple days, create a SEPARATE entry for each day
4. For "lab" sessions (cells that say Lab, IT Lab, etc.), set type to "lab", otherwise "lecture"
5. Use full day names: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday
6. Times must be in 24-hour HH:mm format (e.g. 08:00, 13:30)
7. If teacher name is not visible in a cell, use "TBA"
8. If room is not visible, use "TBA"

OUTPUT: Return ONLY a raw JSON array. No markdown, no code fences, no explanation.
Example format:
[{"day":"Monday","startTime":"08:00","endTime":"09:00","subject":"CS-301","teacher":"Dr. Ali","room":"101","type":"lecture"}]
''';

  static const _textPrompt = '''
You are an expert at extracting university class schedules from text.

EXTRACTION RULES:
1. Extract every class/lecture/lab session mentioned
2. Use full day names: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday
3. Times must be in 24-hour HH:mm format (e.g. 08:00, 13:30)
4. Set type to "lab" if it is a lab session, otherwise "lecture"
5. If teacher is not mentioned, use "TBA". If room is not mentioned, use "TBA"
6. Do NOT skip any entry — extract all of them

OUTPUT: Return ONLY a raw JSON array. No markdown, no code fences, no explanation.
Example format:
[{"day":"Monday","startTime":"08:00","endTime":"09:00","subject":"CS-301","teacher":"Dr. Ali","room":"101","type":"lecture"}]

TIMETABLE TEXT:
''';

  Future<bool> parseImageWithGemini(Uint8List imageBytes) async {
    _isParsing = true;
    _parseError = null;
    _parsedLectures = [];
    notifyListeners();
    try {
      final base64Image = base64Encode(imageBytes);
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                },
                {'type': 'text', 'text': _imagePrompt},
              ],
            }
          ],
          'max_tokens': 8192,
          'temperature': 0.05,
        }),
      );
      return _handleGroqResponse(response.statusCode, response.body);
    } catch (e) {
      _parseError = 'Failed to parse timetable: $e';
      _isParsing = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> parseTextWithGemini(String text) async {
    _isParsing = true;
    _parseError = null;
    _parsedLectures = [];
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a timetable parser. You ONLY output raw valid JSON arrays. Never add markdown, code fences, or any explanation.',
            },
            {
              'role': 'user',
              'content': '$_textPrompt$text',
            },
          ],
          'max_tokens': 8192,
          'temperature': 0.05,
        }),
      );
      return _handleGroqResponse(response.statusCode, response.body);
    } catch (e) {
      _parseError = 'Parsing error: $e';
      _isParsing = false;
      notifyListeners();
      return false;
    }
  }

  bool _handleGroqResponse(int statusCode, String body) {
    if (statusCode == 200) {
      final data = jsonDecode(body);
      final content =
          data['choices']?[0]?['message']?['content'] as String? ?? '';
      if (content.isEmpty) {
        _parseError = 'No response from AI. Please try again.';
        _isParsing = false;
        notifyListeners();
        return false;
      }
      final jsonStr = _extractJson(content);
      final List<dynamic> list = jsonDecode(jsonStr);
      _parsedLectures = list
          .whereType<Map<String, dynamic>>()
          .map((e) => LectureModel.fromJson(e))
          .where((l) => l.subject.isNotEmpty && l.startTime.isNotEmpty)
          .toList();
      if (_parsedLectures.isEmpty) {
        _parseError =
            'No lectures found. Try a clearer image or use Text AI tab.';
        _isParsing = false;
        notifyListeners();
        return false;
      }
      _isParsing = false;
      notifyListeners();
      return true;
    } else {
      _parseError = 'Groq error $statusCode: $body';
      _isParsing = false;
      notifyListeners();
      return false;
    }
  }

  String _extractJson(String text) {
    // Strip markdown code fences if present (```json ... ``` or ``` ... ```)
    final fenceStripped =
        text.replaceAll(RegExp(r'```(?:json)?\s*', multiLine: true), '').trim();
    final startIdx = fenceStripped.indexOf('[');
    final endIdx = fenceStripped.lastIndexOf(']');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return fenceStripped.substring(startIdx, endIdx + 1);
    }
    // Fallback: return as-is
    return fenceStripped;
  }

  Future<bool> saveParsedLectures() async {
    if (_parsedLectures.isEmpty) return false;
    _isSaving = true;
    notifyListeners();
    try {
      _activeTimetableId ??= await _repo.createTimetable('My Timetable');
      // Assign notification IDs before saving
      final lecturesWithIds = _parsedLectures.map((l) => l.copyWith(
        notificationId15min:
            LectureModel.generateNotificationId(l.day, l.startTime, '15'),
        notificationIdStart:
            LectureModel.generateNotificationId(l.day, l.startTime, 'start'),
        notificationsEnabled: true,
      )).toList();
      await _repo.addLectures(_activeTimetableId!, lecturesWithIds);
      _lectures = await _repo.fetchLectures(_activeTimetableId!);
      // Reschedule ALL notifications for full timetable
      final granted = await LectureNotificationService.requestPermissions();
      if (!granted) return false;
      await LectureNotificationService.rescheduleAllForTimetable(_lectures);
      _parsedLectures = [];
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addLectureManually(LectureModel lecture) async {
    _isSaving = true;
    notifyListeners();
    try {
      _activeTimetableId ??= await _repo.createTimetable('My Timetable');
      // Assign notification IDs
      final lectureWithIds = lecture.copyWith(
        notificationId15min: LectureModel.generateNotificationId(
            lecture.day, lecture.startTime, '15'),
        notificationIdStart: LectureModel.generateNotificationId(
            lecture.day, lecture.startTime, 'start'),
        notificationsEnabled: true,
      );
      await _repo.addLecture(_activeTimetableId!, lectureWithIds);
      _lectures = await _repo.fetchLectures(_activeTimetableId!);
      final granted = await LectureNotificationService.requestPermissions();
      if (!granted) return false;
      await LectureNotificationService.rescheduleAllForTimetable(_lectures);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Update an existing persisted lecture. Cancels notifications scheduled
  /// under the OLD day/startTime (since notification IDs are derived from
  /// those), regenerates IDs from the new values, persists, then reschedules.
  Future<bool> updateLecture(LectureModel updated) async {
    if (_activeTimetableId == null) return false;
    _isSaving = true;
    notifyListeners();
    try {
      final old = _lectures.firstWhere(
        (l) => l.id == updated.id,
        orElse: () => throw Exception('Lecture not found'),
      );

      await LectureNotificationService.cancelLectureNotifications(old);

      final withRegeneratedIds = updated.copyWith(
        notificationId15min: LectureModel.generateNotificationId(
            updated.day, updated.startTime, '15'),
        notificationIdStart: LectureModel.generateNotificationId(
            updated.day, updated.startTime, 'start'),
      );

      await _repo.updateLecture(_activeTimetableId!, withRegeneratedIds);
      _lectures = await _repo.fetchLectures(_activeTimetableId!);
      await LectureNotificationService.rescheduleAllForTimetable(_lectures);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update lecture: $e';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteLecture(String lectureId) async {
    if (_activeTimetableId == null) return false;
    try {
      // Cancel notifications for deleted lecture
      final lec = _lectures.firstWhere((l) => l.id == lectureId,
          orElse: () => throw Exception('Lecture not found'));
      await LectureNotificationService.cancelLectureNotifications(lec);
      await _repo.deleteLecture(_activeTimetableId!, lectureId);
      _lectures = await _repo.fetchLectures(_activeTimetableId!);
      notifyListeners();
      // Reschedule remaining
      await LectureNotificationService.rescheduleAllForTimetable(_lectures);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> resetTimetable() async {
    _isLoading = true;
    notifyListeners();
    try {
      await LectureNotificationService.cancelAllNotifications();
      await _repo.deleteActiveTimetable();
      _activeTimetableId = null;
      _lectures = [];
      _parsedLectures = [];
      _error = null;
    } catch (e) {
      _error = 'Failed to reset: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  void removeParsedLecture(int index) {
    _parsedLectures.removeAt(index);
    notifyListeners();
  }

  void updateParsedLecture(int index, LectureModel updated) {
    if (index >= 0 && index < _parsedLectures.length) {
      _parsedLectures[index] = updated;
      notifyListeners();
    }
  }

  void setTab(int tab) {
    _selectedTab = tab;
    notifyListeners();
  }

  Future<void> toggleLectureNotification(
      String lectureId, bool enabled) async {
    if (_activeTimetableId == null) return;
    try {
      final lec = _lectures.firstWhere((l) => l.id == lectureId);
      final updated = lec.copyWith(notificationsEnabled: enabled);
      await _repo.updateLecture(_activeTimetableId!, updated);
      final idx = _lectures.indexWhere((l) => l.id == lectureId);
      if (idx != -1) {
        _lectures[idx] = updated;
        notifyListeners();
      }
      await LectureNotificationService.rescheduleAllForTimetable(_lectures);
    } catch (e) {
      _error = 'Failed to update notification: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    _parseError = null;
    notifyListeners();
  }
}
