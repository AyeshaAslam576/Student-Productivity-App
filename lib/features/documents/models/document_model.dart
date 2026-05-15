import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/scanner_service.dart' show ScanFilter, PdfPageSize;

enum DocumentType { pdf, image, scanned, generated }

enum DocumentSource { scanned, imported, generated, received }

class DocumentModel {
  final String id;
  final String userId;
  final String title;
  final String? subjectTag;
  final DocumentType type;
  final DocumentSource source;
  final String localPath;
  final String? cloudUrl;
  final int fileSizeBytes;
  final int pageCount;
  final String? extractedText;
  final String? aiSummary;
  final List<String> tags;
  final bool isFavorite;
  final String folder;
  final DateTime createdAt;
  final DateTime lastOpenedAt;
  final List<String> pageImagePaths;
  final String? thumbnailPath;
  final ScanFilter appliedFilter;
  final PdfPageSize pageSize;
  final bool hasOcrText;
  final int? scanDurationMs;

  const DocumentModel({
    required this.id,
    required this.userId,
    required this.title,
    this.subjectTag,
    required this.type,
    required this.source,
    required this.localPath,
    this.cloudUrl,
    required this.fileSizeBytes,
    required this.pageCount,
    this.extractedText,
    this.aiSummary,
    this.tags = const [],
    this.isFavorite = false,
    this.folder = 'General',
    required this.createdAt,
    required this.lastOpenedAt,
    this.pageImagePaths = const [],
    this.thumbnailPath,
    this.appliedFilter = ScanFilter.auto,
    this.pageSize = PdfPageSize.a4,
    this.hasOcrText = false,
    this.scanDurationMs,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '${fileSizeBytes}B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get formattedDate {
    final diff = DateTime.now().difference(lastOpenedAt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${lastOpenedAt.day}/${lastOpenedAt.month}/${lastOpenedAt.year}';
  }

  String get pageCountLabel => pageCount == 1 ? '1 page' : '$pageCount pages';

  factory DocumentModel.fromMap(String id, Map<String, dynamic> map) {
    return DocumentModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subjectTag: map['subjectTag'] as String?,
      type: DocumentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DocumentType.pdf,
      ),
      source: DocumentSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => DocumentSource.imported,
      ),
      localPath: map['localPath'] as String? ?? '',
      cloudUrl: map['cloudUrl'] as String?,
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
      pageCount: map['pageCount'] as int? ?? 1,
      extractedText: map['extractedText'] as String?,
      aiSummary: map['aiSummary'] as String?,
      tags: List<String>.from(map['tags'] as List<dynamic>? ?? const []),
      isFavorite: map['isFavorite'] as bool? ?? false,
      folder: map['folder'] as String? ?? 'General',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastOpenedAt:
          (map['lastOpenedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pageImagePaths: List<String>.from(
        map['pageImagePaths'] as List<dynamic>? ?? const [],
      ),
      thumbnailPath: map['thumbnailPath'] as String?,
      appliedFilter: ScanFilter.values.firstWhere(
        (e) => e.name == map['appliedFilter'],
        orElse: () => ScanFilter.auto,
      ),
      pageSize: PdfPageSize.values.firstWhere(
        (e) => e.name == map['pageSize'],
        orElse: () => PdfPageSize.a4,
      ),
      hasOcrText: map['hasOcrText'] as bool? ?? false,
      scanDurationMs: map['scanDurationMs'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'subjectTag': subjectTag,
      'type': type.name,
      'source': source.name,
      'localPath': localPath,
      'cloudUrl': null,
      'fileSizeBytes': fileSizeBytes,
      'pageCount': pageCount,
      'extractedText': extractedText,
      'aiSummary': aiSummary,
      'tags': tags,
      'isFavorite': isFavorite,
      'folder': folder,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastOpenedAt': Timestamp.fromDate(lastOpenedAt),
      'pageImagePaths': pageImagePaths,
      'thumbnailPath': thumbnailPath,
      'appliedFilter': appliedFilter.name,
      'pageSize': pageSize.name,
      'hasOcrText': hasOcrText,
      'scanDurationMs': scanDurationMs,
    };
  }

  DocumentModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? subjectTag,
    DocumentType? type,
    DocumentSource? source,
    String? localPath,
    String? cloudUrl,
    int? fileSizeBytes,
    int? pageCount,
    String? extractedText,
    String? aiSummary,
    List<String>? tags,
    bool? isFavorite,
    String? folder,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
    List<String>? pageImagePaths,
    String? thumbnailPath,
    ScanFilter? appliedFilter,
    PdfPageSize? pageSize,
    bool? hasOcrText,
    int? scanDurationMs,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      subjectTag: subjectTag ?? this.subjectTag,
      type: type ?? this.type,
      source: source ?? this.source,
      localPath: localPath ?? this.localPath,
      cloudUrl: cloudUrl ?? this.cloudUrl,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      extractedText: extractedText ?? this.extractedText,
      aiSummary: aiSummary ?? this.aiSummary,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      folder: folder ?? this.folder,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      pageImagePaths: pageImagePaths ?? this.pageImagePaths,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      appliedFilter: appliedFilter ?? this.appliedFilter,
      pageSize: pageSize ?? this.pageSize,
      hasOcrText: hasOcrText ?? this.hasOcrText,
      scanDurationMs: scanDurationMs ?? this.scanDurationMs,
    );
  }
}
