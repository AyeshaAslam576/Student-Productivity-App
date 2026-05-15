import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

import '../../documents/services/pdf_service.dart';
import '../models/ai_session_model.dart';
import '../repositories/ai_session_repository.dart';

enum AiState { idle, loading, done, error }

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'content': content,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        content: map['content'] as String? ?? '',
        isUser: map['isUser'] as bool? ?? false,
        timestamp:
            DateTime.tryParse(map['timestamp'] as String? ?? '') ??
                DateTime.now(),
      );
}

class AiViewModel extends ChangeNotifier {
  final String groqApiKey;
  final AiSessionRepository _sessionRepo;

  AiViewModel({
    required this.groqApiKey,
    required AiSessionRepository sessionRepository,
  }) : _sessionRepo = sessionRepository {
    loadRecentSessions();
  }

  AiState _summaryState = AiState.idle;
  AiState _grammarState = AiState.idle;
  AiState _chatState = AiState.idle;

  String _summaryResult = '';
  String _grammarOriginal = '';
  String _grammarCorrected = '';
  List<String> _grammarErrors = [];
  List<GrammarError> _grammarErrorDetails = [];
  List<ChatMessage> _chatMessages = [];
  String? _error;
  List<AiSession> _recentSessions = [];
  bool isLoadingSessions = false;
  String _currentInput = '';
  InputSource _inputSource = InputSource.pastedText;
  File? _uploadedFile;

  /// Stable ID for the current conversation.
  /// Null = no active session yet (first message will create one).
  String? _activeChatSessionId;

  AiSessionRepository get sessionRepository => _sessionRepo;

  AiState get summaryState => _summaryState;
  AiState get grammarState => _grammarState;
  AiState get chatState => _chatState;
  String get summaryResult => _summaryResult;
  String get grammarOriginal => _grammarOriginal;
  String get grammarCorrected => _grammarCorrected;
  List<String> get grammarErrors => _grammarErrors;
  List<GrammarError> get grammarErrorDetails => _grammarErrorDetails;
  List<ChatMessage> get chatMessages => _chatMessages;
  String? get error => _error;
  List<AiSession> get recentSessions => _recentSessions;
  String get currentInput => _currentInput;
  InputSource get inputSource => _inputSource;
  File? get uploadedFile => _uploadedFile;

  Future<void> loadRecentSessions() async {
    isLoadingSessions = true;
    notifyListeners();
    try {
      _recentSessions = await _sessionRepo.watchRecentSessions(limit: 10).first;
      await _sessionRepo.clearOldSessions();
    } catch (e) {
      _error = e.toString();
    }
    isLoadingSessions = false;
    notifyListeners();
  }

  void setInputSource(InputSource source) {
    _inputSource = source;
    notifyListeners();
  }

  void setCurrentInput(String value) {
    _currentInput = value;
    if (value.trim().isNotEmpty) {
      _inputSource = InputSource.pastedText;
    }
  }

  Future<void> uploadFile(File file) async {
    _uploadedFile = file;
    _error = null;
    notifyListeners();
    try {
      final text = await _extractTextFromFile(file);
      _currentInput = text;
      _inputSource = InputSource.uploadedFile;
    } catch (e) {
      _error = 'Failed to extract text: $e';
    }
    notifyListeners();
  }

  Future<void> summarize(String text, {String style = 'Detailed'}) async {
    _summaryState = AiState.loading;
    _error = null;
    notifyListeners();
    try {
      final stylePrompt = switch (style) {
        'Brief' => 'Provide a very brief 2-3 sentence summary.',
        'Bullet Points' => 'Provide a bullet-point summary with key points.',
        _ => 'Provide a detailed summary with main ideas clearly explained.',
      };
      final result = await _callGroq(
        model: 'llama-3.3-70b-versatile',
        systemPrompt:
            'You are an expert academic summarizer helping university students understand content quickly.',
        userMessage: '$stylePrompt\n\nText to summarize:\n$text',
      );
      _summaryResult = result;
      _summaryState = AiState.done;
      await saveSummarySession(text, result, style);
    } catch (e) {
      _error = e.toString();
      _summaryState = AiState.error;
    }
    notifyListeners();
  }

  Future<void> checkGrammar(String text) async {
    _grammarState = AiState.loading;
    _grammarOriginal = text;
    _grammarCorrected = '';
    _grammarErrors = [];
    _grammarErrorDetails = [];
    _error = null;
    notifyListeners();
    try {
      final result = await _callGroq(
        model: 'llama-3.3-70b-versatile',
        systemPrompt:
            'You are a grammar expert. When given text, return a JSON object with: {"corrected": "the corrected text", "errors": ["list of grammar issues found"]}. Return ONLY the JSON.',
        userMessage: 'Check and correct the grammar in this text:\n$text',
      );
      final jsonStr = _extractJson(result);
      final data = jsonDecode(jsonStr);
      _grammarCorrected = data['corrected'] ?? text;
      _grammarErrors = List<String>.from(data['errors'] ?? []);
      _grammarErrorDetails = _toGrammarDetails(_grammarErrors, text);
      _grammarState = AiState.done;
      await saveGrammarSession(text, _grammarCorrected, _grammarErrorDetails);
    } catch (e) {
      _error = e.toString();
      _grammarState = AiState.error;
    }
    notifyListeners();
  }

  Future<void> sendChatMessage(String message) async {
    // Assign a stable session ID the first time a message is sent.
    _activeChatSessionId ??=
        DateTime.now().microsecondsSinceEpoch.toString();

    _chatMessages.add(ChatMessage(
      content: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _chatState = AiState.loading;
    notifyListeners();
    try {
      final allMessages = _chatMessages.toList();
      final history = (allMessages.length > 10
              ? allMessages.sublist(allMessages.length - 10)
              : allMessages)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

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
                  'You are an academic assistant helping university students in Pakistan. Be concise, helpful, and encouraging. Answer academic questions clearly.'
            },
            ...history,
          ],
          'max_tokens': 1024,
          'temperature': 0.7,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        _chatMessages.add(ChatMessage(
          content: content,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _chatState = AiState.done;
        // Upsert the session — same ID throughout the whole conversation.
        await saveChatSession();
      } else {
        _error =
            'Chat error ${response.statusCode}: ${response.body}';
        _chatState = AiState.error;
      }
    } catch (e) {
      _error = e.toString();
      _chatState = AiState.error;
    }
    notifyListeners();
  }

  Future<void> saveSummarySession(
    String input,
    String output,
    String style,
  ) async {
    final now = DateTime.now();
    final session = AiSession(
      id: now.microsecondsSinceEpoch.toString(),
      userId: _sessionRepo.userId,
      type: SessionType.summarizer,
      inputSource: _inputSource.name,
      originalInput: _truncatePreview(input),
      output: output,
      metadata: {'style': style},
      isFavorite: false,
      createdAt: now,
      lastAccessedAt: now,
    );
    await _sessionRepo.saveSession(session);
    await loadRecentSessions();
  }

  Future<void> saveGrammarSession(
    String input,
    String corrected,
    List<GrammarError> errors,
  ) async {
    final now = DateTime.now();
    final session = AiSession(
      id: now.microsecondsSinceEpoch.toString(),
      userId: _sessionRepo.userId,
      type: SessionType.grammar,
      inputSource: _inputSource.name,
      originalInput: _truncatePreview(input),
      output: corrected,
      metadata: {
        'errors': errors.map((e) => e.toMap()).toList(),
      },
      isFavorite: false,
      createdAt: now,
      lastAccessedAt: now,
    );
    await _sessionRepo.saveSession(session);
    await loadRecentSessions();
  }

  Future<void> saveChatSession() async {
    if (_chatMessages.isEmpty || _activeChatSessionId == null) return;
    final now = DateTime.now();

    // Title = first user message (truncated to 60 chars)
    final firstUserMsg = _chatMessages
        .firstWhere((m) => m.isUser, orElse: () => _chatMessages.first)
        .content;
    final title = firstUserMsg.length > 60
        ? firstUserMsg.substring(0, 60)
        : firstUserMsg;

    final session = AiSession(
      id: _activeChatSessionId!,
      userId: _sessionRepo.userId,
      type: SessionType.chatbot,
      inputSource: 'chat',
      originalInput: title,           // used as the drawer preview title
      output: _chatMessages.last.content,
      metadata: {
        'messages': _chatMessages.map((m) => m.toMap()).toList(),
      },
      isFavorite: false,
      createdAt: now,
      lastAccessedAt: now,
    );
    await _sessionRepo.saveSession(session);
    await loadRecentSessions();
  }

  Future<void> saveTtsSession({
    required String input,
    required Map<String, dynamic> metadata,
  }) async {
    final now = DateTime.now();
    final session = AiSession(
      id: now.microsecondsSinceEpoch.toString(),
      userId: _sessionRepo.userId,
      type: SessionType.tts,
      inputSource: _inputSource.name,
      originalInput: _truncatePreview(input),
      output: '',
      metadata: metadata,
      isFavorite: false,
      createdAt: now,
      lastAccessedAt: now,
    );
    await _sessionRepo.saveSession(session);
    await loadRecentSessions();
  }

  /// Synchronously restores the session state and immediately calls
  /// [notifyListeners], then fires the Firestore "last accessed" update in
  /// the background.  Call this while the drawer is still in the tree so the
  /// rebuild targets a live widget — NOT after [Navigator.pop].
  void switchToChatSession(AiSession session) {
    _chatMessages = session.chatHistory;
    _chatState = AiState.done;
    _activeChatSessionId = session.id;
    _currentInput = session.originalInput;
    notifyListeners(); // fires while drawer is still open → safe rebuild
    // Background: update timestamp and refresh session list.
    _sessionRepo
        .updateLastAccessed(session.id)
        .then((_) => loadRecentSessions())
        .catchError((_) {});
  }

  /// Full async version — used for non-chat sessions (summarizer, grammar).
  Future<void> loadSession(AiSession session) async {
    _inputSource = InputSource.values.firstWhere(
      (value) => value.name == session.inputSource,
      orElse: () => InputSource.pastedText,
    );
    _currentInput = session.originalInput;

    if (session.type == SessionType.summarizer) {
      _summaryResult = session.output;
      _summaryState = AiState.done;
    } else if (session.type == SessionType.grammar) {
      _grammarOriginal = session.originalInput;
      _grammarCorrected = session.output;
      _grammarErrorDetails = session.grammarErrors;
      _grammarErrors = _grammarErrorDetails.map((e) => e.issue).toList();
      _grammarState = AiState.done;
    } else if (session.type == SessionType.chatbot) {
      // For chatbot, prefer the synchronous path via switchToChatSession.
      switchToChatSession(session);
      return;
    }

    await _sessionRepo.updateLastAccessed(session.id);
    notifyListeners();
  }

  Future<void> toggleSessionFavorite(String sessionId) async {
    final session = _recentSessions.firstWhere((s) => s.id == sessionId);
    await _sessionRepo.toggleFavorite(sessionId, !session.isFavorite);
    await loadRecentSessions();
  }

  Future<void> deleteSession(String sessionId) async {
    await _sessionRepo.deleteSession(sessionId);
    await loadRecentSessions();
  }

  Future<void> renameSession(String sessionId, String newTitle) async {
    await _sessionRepo.renameSession(sessionId, newTitle.trim());
    await loadRecentSessions();
  }

  Future<String> _callGroq({
    required String model,
    required String systemPrompt,
    required String userMessage,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $groqApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'max_tokens': 2048,
        'temperature': 0.3,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception(
        'Groq API error ${response.statusCode}: ${response.body}');
  }

  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1) return text.substring(start, end + 1);
    return text;
  }

  Future<String> _extractTextFromFile(File file) async {
    final path = file.path.toLowerCase();
    if (path.endsWith('.pdf')) {
      return PdfService.extractText(file.path);
    }
    if (path.endsWith('.txt')) {
      return file.readAsString();
    }
    if (path.endsWith('.docx')) {
      return _extractDocxText(file);
    }
    if (path.endsWith('.doc')) {
      throw Exception(
          'Old .doc format is not supported. Please save the file as .docx or .pdf and try again.');
    }
    if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final inputImage = InputImage.fromFilePath(file.path);
        final result = await recognizer.processImage(inputImage);
        return result.text.trim();
      } finally {
        await recognizer.close();
      }
    }
    throw Exception('Unsupported file type');
  }

  Future<String> _extractDocxText(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('word/document.xml');
    if (entry == null) throw Exception('Invalid DOCX: word/document.xml not found.');
    final xmlString = utf8.decode(entry.content as List<int>);
    // Insert newlines at paragraph boundaries before stripping tags.
    final withBreaks = xmlString
        .replaceAll(RegExp(r'<w:p[ >]'), '\n<w:p ')
        .replaceAll(RegExp(r'<w:br[^/]*/?>'), '\n');
    // Strip all XML tags.
    final plain = withBreaks
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (plain.isEmpty) throw Exception('No readable text found in the DOCX file.');
    return plain;
  }

  List<GrammarError> _toGrammarDetails(List<String> errors, String text) {
    return errors.asMap().entries.map((entry) {
      final issue = entry.value;
      final keyword = issue.split(' ').first.toLowerCase();
      final position = text.toLowerCase().indexOf(keyword);
      return GrammarError(
        issue: issue,
        suggestion: 'Apply suggested correction',
        position: position < 0 ? 0 : position,
      );
    }).toList();
  }

  String _truncatePreview(String input) {
    final trimmed = input.trim();
    if (trimmed.length <= 500) return trimmed;
    return trimmed.substring(0, 500);
  }

  void clearChat() {
    _chatMessages = [];
    _chatState = AiState.idle;
    _activeChatSessionId = null;   // next message starts a fresh session
    notifyListeners();
  }

  void clearSummary() {
    _summaryResult = '';
    _summaryState = AiState.idle;
    notifyListeners();
  }

  void clearGrammar() {
    _grammarOriginal = '';
    _grammarCorrected = '';
    _grammarErrors = [];
    _grammarErrorDetails = [];
    _grammarState = AiState.idle;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
