import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/groq_service.dart';
import '../models/semester_model.dart';
import '../repositories/cgpa_repository.dart';

class CgpaViewModel extends ChangeNotifier {
  final CgpaRepository _repo;
  static const _targetKey = 'brainup_target_cgpa';
  StreamSubscription<List<SemesterModel>>? _sub;

  CgpaViewModel(this._repo) {
    _initStream();
    _loadTargetCgpa();
    _loadUserMeta();
  }

  List<SemesterModel> _semesters = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  Set<String> _expandedSemesters = {};
  double? _targetCgpa;
  String? _aiMotivation;
  List<String> _aiTips = [];
  String? _aiGoal;
  bool _isLoadingMotivation = false;

  List<SemesterModel> get semesters => _semesters;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  Set<String> get expandedSemesters => _expandedSemesters;
  double? get targetCgpa => _targetCgpa;
  String? get aiMotivation => _aiMotivation;
  List<String> get aiTips => _aiTips;
  String? get aiGoal => _aiGoal;
  bool get isLoadingMotivation => _isLoadingMotivation;

  double get cgpa {
    if (_semesters.isEmpty) return 0.0;
    double totalQP = 0;
    int totalCH = 0;
    for (final sem in _semesters) {
      for (final sub in sem.subjects) {
        totalQP += sub.qualityPoints;
        totalCH += sub.creditHours;
      }
    }
    if (totalCH == 0) return 0.0;
    return double.parse((totalQP / totalCH).toStringAsFixed(2));
  }

  int get totalCredits =>
      _semesters.fold(0, (s, sem) => s + sem.totalCredits);

  List<FlSpotData> get cgpaTrend {
    return _semesters
        .asMap()
        .entries
        .map((e) => FlSpotData(e.key.toDouble(), e.value.gpa))
        .toList();
  }

  bool isExpanded(String semId) => _expandedSemesters.contains(semId);

  void toggleExpand(String semId) {
    if (_expandedSemesters.contains(semId)) {
      _expandedSemesters.remove(semId);
    } else {
      _expandedSemesters.add(semId);
    }
    notifyListeners();
  }

  Future<void> loadSemesters() async {
    final ready = Completer<void>();
    await _sub?.cancel();
    _initStream(onReady: () {
      if (!ready.isCompleted) ready.complete();
    });
    return ready.future;
  }

  Future<bool> addSemester(SemesterModel semester) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _repo.addSemester(semester);
      await loadSemesters();
      await generateMotivation(semester, cgpa);
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

  Future<bool> deleteSemester(String semId) async {
    try {
      await _repo.deleteSemester(semId);
      _semesters.removeWhere((s) => s.id == semId);
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

  void clearMotivation() {
    _aiMotivation = null;
    _aiTips = [];
    _aiGoal = null;
    notifyListeners();
  }

  Future<void> setTargetCgpa(double target) async {
    _targetCgpa = target;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_targetKey, target);
  }

  String get targetInsight {
    if (_targetCgpa == null || cgpa >= _targetCgpa!) return '';
    final currentCH = totalCredits;
    final neededGpa = ((_targetCgpa! * (currentCH + 18)) - (cgpa * currentCH)) / 18;
    if (neededGpa > 4.0) {
      return 'Target requires above 4.0 — consider adjusting your goal.';
    }
    if (neededGpa < 0) return 'You\'ve already exceeded your target!';
    return 'You need an avg GPA of ${neededGpa.toStringAsFixed(2)} over your next semester (18 credits) to reach ${_targetCgpa!.toStringAsFixed(1)} CGPA.';
  }

  Future<void> generateMotivation(SemesterModel semester, double newCgpa) async {
    _isLoadingMotivation = true;
    notifyListeners();
    try {
      final weakSubjects = semester.subjects
          .where((s) => s.gradePoints < 2.5)
          .map((s) => '${s.name} (${s.grade})')
          .join(', ');
      final prompt = '''
A Pakistani university student just completed ${semester.name} with SGPA ${semester.gpa.toStringAsFixed(2)}.
Cumulative CGPA is now ${newCgpa.toStringAsFixed(2)}.
${weakSubjects.isNotEmpty ? 'Weak subjects: $weakSubjects' : 'No subjects below B-.'}
Provide:
1. A short emotional motivational message (2-3 sentences, warm and encouraging)
2. 3 specific study improvement tips based on their grade profile
3. One actionable goal for next semester
Return as JSON: {"motivation": "...", "tips": ["...", "...", "..."], "goal": "..."}
      ''';
      final raw = await GroqService.chat(
        model: 'llama-3.3-70b-versatile',
        messages: [{'role': 'user', 'content': prompt}],
        maxTokens: 512,
        temperature: 0.7,
      );
      final jsonStr = _extractJson(raw);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      _aiMotivation = parsed['motivation'] as String?;
      _aiTips = List<String>.from(parsed['tips'] ?? const []);
      _aiGoal = parsed['goal'] as String?;
      if (_aiGoal != null) {
        await _repo.saveUserMeta({'lastAiGoal': _aiGoal});
      }
    } catch (_) {
      _aiMotivation = 'You are improving one semester at a time. Keep your momentum and stay consistent with your study plan.';
      _aiTips = const [
        'Review weak subjects twice a week in focused 45-minute sessions.',
        'Solve past papers under timed conditions every weekend.',
        'Track your study targets daily and reflect every Sunday.',
      ];
      _aiGoal = 'Aim for at least one grade improvement in your weakest subject next semester.';
    } finally {
      _isLoadingMotivation = false;
      notifyListeners();
    }
  }

  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }

  void _initStream({VoidCallback? onReady}) {
    _isLoading = true;
    _error = null;
    notifyListeners();
    _sub = _repo.watchSemesters().listen(
      (semesters) {
        _semesters = semesters;
        _isLoading = false;
        _error = null;
        notifyListeners();
        onReady?.call();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
        onReady?.call();
      },
    );
  }

  Future<void> _loadTargetCgpa() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_targetKey);
    if (saved != null) {
      _targetCgpa = saved;
      notifyListeners();
    }
  }

  Future<void> _loadUserMeta() async {
    try {
      final meta = await _repo.getUserMeta();
      if (meta['lastAiGoal'] != null) {
        _aiGoal = meta['lastAiGoal'] as String;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class FlSpotData {
  final double x;
  final double y;
  const FlSpotData(this.x, this.y);
}
