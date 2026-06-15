import 'dart:convert';

import '../../../core/services/groq_service.dart';

class DocAiService {
  const DocAiService();

  Future<DocAiAnalysis> analyzeDocument(String extractedText) async {
    final raw = await _chat(
      systemPrompt:
          "You are an academic document analyzer for university students in Pakistan. Analyze the provided document text and return a JSON with: {type:'exam_paper'|'lecture_notes'|'assignment'|'research_paper'|'textbook'|'other',subject:string,summary:string,keyTopics:[string],importantDates:[{label:string,date:string}],suggestedTasks:[{title:string,type:string,priority:string}],studyTips:[string],difficulty:'easy'|'medium'|'hard'}",
      userPrompt: extractedText,
      maxTokens: 2048,
    );
    final map = _extractJsonMap(raw);
    return DocAiAnalysis.fromJson(map);
  }

  Future<String> chatWithDocument(
    String extractedText,
    String question,
    List<Map<String, dynamic>> history,
  ) async {
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            'You are helping a university student understand this document. Answer questions based ONLY on the document content provided. Be concise and academic.',
      },
      {'role': 'user', 'content': 'Document content:\n$extractedText'},
      ...history,
      {'role': 'user', 'content': question},
    ];
    return _chatRaw(messages, maxTokens: 1024);
  }

  Future<List<FlashCard>> generateFlashcards(String extractedText) async {
    final raw = await _chat(
      systemPrompt:
          'Generate 10-15 study flashcards in JSON array: [{"question":"...","answer":"..."}]. Return only JSON.',
      userPrompt: extractedText,
      maxTokens: 2048,
    );
    final list = _extractJsonList(raw);
    return list
        .map((e) =>
            FlashCard(question: '${e['question']}', answer: '${e['answer']}'))
        .toList();
  }

  Future<List<ExamQuestion>> extractQuestions(String extractedText) async {
    final raw = await _chat(
      systemPrompt:
          'Extract exam/quiz questions in JSON array: [{"question":"...","options":["A","B"],"answer":"..."}]. If non-MCQ, options can be empty.',
      userPrompt: extractedText,
      maxTokens: 2048,
    );
    final list = _extractJsonList(raw);
    return list
        .map(
          (e) => ExamQuestion(
            question: '${e['question']}',
            options: List<String>.from(e['options'] ?? const []),
            answer: e['answer'] as String?,
          ),
        )
        .toList();
  }

  Future<String> suggestTitle(String extractedText) async {
    return _chat(
      systemPrompt:
          'Return a clean concise academic title from given text (max 8 words). Return plain text only.',
      userPrompt: extractedText,
      maxTokens: 40,
    );
  }

  Future<String> _chat({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 1024,
  }) async {
    return _chatRaw([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ], maxTokens: maxTokens);
  }

  Future<String> _chatRaw(List<Map<String, dynamic>> messages,
      {required int maxTokens}) async {
    return GroqService.chat(
      model: 'llama-3.3-70b-versatile',
      messages: messages,
      maxTokens: maxTokens,
      temperature: 0.2,
    );
  }

  Map<String, dynamic> _extractJsonMap(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return {};
    final raw = text.substring(start, end + 1);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _extractJsonList(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return [];
    final raw = text.substring(start, end + 1);
    final parsed = jsonDecode(raw) as List<dynamic>;
    return parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

class DocAiAnalysis {
  final String documentType;
  final String detectedSubject;
  final String summary;
  final List<String> keyTopics;
  final List<ImportantDate> importantDates;
  final List<SuggestedTask> suggestedTasks;
  final List<String> studyTips;
  final String difficulty;

  const DocAiAnalysis({
    required this.documentType,
    required this.detectedSubject,
    required this.summary,
    required this.keyTopics,
    required this.importantDates,
    required this.suggestedTasks,
    required this.studyTips,
    required this.difficulty,
  });

  factory DocAiAnalysis.fromJson(Map<String, dynamic> json) {
    return DocAiAnalysis(
      documentType: json['type'] as String? ?? 'other',
      detectedSubject: json['subject'] as String? ?? 'General',
      summary: json['summary'] as String? ?? '',
      keyTopics: List<String>.from(json['keyTopics'] ?? const []),
      importantDates: (json['importantDates'] as List<dynamic>? ?? const [])
          .map((e) => ImportantDate.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      suggestedTasks: (json['suggestedTasks'] as List<dynamic>? ?? const [])
          .map((e) => SuggestedTask.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      studyTips: List<String>.from(json['studyTips'] ?? const []),
      difficulty: json['difficulty'] as String? ?? 'medium',
    );
  }
}

class ImportantDate {
  final String label;
  final String date;
  const ImportantDate({required this.label, required this.date});
  factory ImportantDate.fromJson(Map<String, dynamic> json) {
    return ImportantDate(
      label: json['label'] as String? ?? '',
      date: json['date'] as String? ?? '',
    );
  }
}

class SuggestedTask {
  final String title;
  final String type;
  final String priority;
  const SuggestedTask({
    required this.title,
    required this.type,
    required this.priority,
  });
  factory SuggestedTask.fromJson(Map<String, dynamic> json) {
    return SuggestedTask(
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'other',
      priority: json['priority'] as String? ?? 'medium',
    );
  }
}

class FlashCard {
  final String question;
  final String answer;
  const FlashCard({required this.question, required this.answer});
}

class ExamQuestion {
  final String question;
  final List<String> options;
  final String? answer;
  const ExamQuestion({
    required this.question,
    this.options = const [],
    this.answer,
  });
}
