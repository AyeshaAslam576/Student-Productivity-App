import '../viewmodels/ai_viewmodel.dart';

enum SessionType { summarizer, grammar, chatbot, tts }

enum InputSource { pastedText, uploadedFile, linkedDocument }

class AiSession {
  final String id;
  final String userId;
  final SessionType type;
  final String inputSource;
  final String originalInput;
  final String output;
  final Map<String, dynamic> metadata;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime lastAccessedAt;

  const AiSession({
    required this.id,
    required this.userId,
    required this.type,
    required this.inputSource,
    required this.originalInput,
    required this.output,
    required this.metadata,
    required this.isFavorite,
    required this.createdAt,
    required this.lastAccessedAt,
  });

  List<GrammarError> get grammarErrors =>
      (metadata['errors'] as List<dynamic>?)
          ?.map((e) => GrammarError.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList() ??
      [];

  List<ChatMessage> get chatHistory =>
      (metadata['messages'] as List<dynamic>?)
          ?.map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList() ??
      [];

  String get formattedDate {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays == 0) {
      return 'Today ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${createdAt.day}/${createdAt.month}';
  }

  String get preview {
    final snippet = originalInput.length > 60
        ? '${originalInput.substring(0, 60)}...'
        : originalInput;
    return snippet.replaceAll('\n', ' ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'inputSource': inputSource,
      'originalInput': originalInput,
      'output': output,
      'metadata': metadata,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
    };
  }

  factory AiSession.fromMap(Map<String, dynamic> map) {
    return AiSession(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      type: SessionType.values.firstWhere(
        (e) => e.name == (map['type'] as String?),
        orElse: () => SessionType.chatbot,
      ),
      inputSource: map['inputSource'] as String? ?? InputSource.pastedText.name,
      originalInput: map['originalInput'] as String? ?? '',
      output: map['output'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      isFavorite: map['isFavorite'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastAccessedAt:
          DateTime.tryParse(map['lastAccessedAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  AiSession copyWith({
    String? id,
    String? userId,
    SessionType? type,
    String? inputSource,
    String? originalInput,
    String? output,
    Map<String, dynamic>? metadata,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
  }) {
    return AiSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      inputSource: inputSource ?? this.inputSource,
      originalInput: originalInput ?? this.originalInput,
      output: output ?? this.output,
      metadata: metadata ?? this.metadata,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }
}

class GrammarError {
  final String issue;
  final String suggestion;
  final int position;

  const GrammarError({
    required this.issue,
    required this.suggestion,
    required this.position,
  });

  Map<String, dynamic> toMap() => {
        'issue': issue,
        'suggestion': suggestion,
        'position': position,
      };

  factory GrammarError.fromMap(Map<String, dynamic> map) => GrammarError(
        issue: map['issue'] as String? ?? '',
        suggestion: map['suggestion'] as String? ?? '',
        position: map['position'] as int? ?? 0,
      );
}
