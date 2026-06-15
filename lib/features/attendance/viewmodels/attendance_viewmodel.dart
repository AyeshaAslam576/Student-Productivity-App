import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../repositories/attendance_repository.dart';

class AttendanceViewModel extends ChangeNotifier {
  final AttendanceRepository _repo;

  AttendanceViewModel(this._repo) {
    loadAttendance();
  }

  List<AttendanceModel> _attendance = [];
  List<String> _timetableSubjects = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  List<AttendanceModel> get attendance => _attendance;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  void syncSubjectsFromTimetable(List<String> subjects) {
    _timetableSubjects = subjects;
    notifyListeners();
  }

  List<String> get subjectSuggestions => _timetableSubjects
      .where((s) => !_attendance.any((a) => a.subjectName == s))
      .toList();

  List<AttendanceModel> get criticalSubjects =>
      _attendance.where((a) => a.isCritical || a.isWarning).toList();

  double get overallPercentage {
    if (_attendance.isEmpty) return 0;
    final total = _attendance.fold<int>(0, (s, a) => s + a.totalClasses);
    final present = _attendance.fold<int>(0, (s, a) => s + a.present);
    if (total == 0) return 0;
    return (present / total) * 100;
  }

  Future<void> loadAttendance() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _attendance = await _repo.fetchAttendance();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> markAttendance(String subjectId, String status) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _repo.markAttendance(subjectId, status);
      await loadAttendance();
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

  Future<bool> addSubject(String name) async {
    try {
      final id = await _repo.createSubjectAttendance(name);
      _attendance.add(AttendanceModel(
        id: id,
        subjectName: name,
        totalClasses: 0,
        present: 0,
        absent: 0,
      ));
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSubject(String subjectId) async {
    try {
      await _repo.deleteSubjectAttendance(subjectId);
      _attendance.removeWhere((a) => a.id == subjectId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
