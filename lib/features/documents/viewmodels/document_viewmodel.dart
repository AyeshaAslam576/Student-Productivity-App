import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/repositories/task_repository.dart';
import '../services/doc_ai_service.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';

enum SortOption { lastOpened, createdAt, name, size }

class DocumentViewModel extends ChangeNotifier {
  final DocumentRepository repository;
  final DocAiService aiService;

  DocumentViewModel({
    required this.repository,
    required this.aiService,
  }) {
    _sub = repository.watchAllDocuments().listen((docs) {
      _documents = docs;
      notifyListeners();
    });
  }

  StreamSubscription<List<DocumentModel>>? _sub;

  List<DocumentModel> _documents = [];
  bool isLoading = false;
  String? errorMessage;

  String _searchQuery = '';
  String? _selectedSubject;
  DocumentType? _selectedType;
  bool _favoritesOnly = false;
  String _selectedFolder = 'All';
  SortOption _sortBy = SortOption.lastOpened;

  List<File> _scannedPages = [];
  List<File> get scannedPages => _scannedPages;
  bool isScanning = false;

  // Scanning workflow state (CamScanner-like flow)
  List<File> _rawPages = []; // unfiltered captured images
  List<File> _processedPages = []; // after filter applied
  int _previewIndex = 0; // which page is being previewed in editor
  ScanFilter _selectedFilter = ScanFilter.auto;
  PdfPageSize _selectedPageSize = PdfPageSize.a4;
  bool isScanProcessing = false; // true during filter/OCR/PDF generation
  double scanProgress = 0.0; // 0.0 – 1.0 progress indicator
  String? ocrText; // extracted text from current scan session
  bool isOcrRunning = false;

  DocAiAnalysis? currentAnalysis;
  bool isAnalyzing = false;
  List<Map<String, String>> chatHistory = [];
  bool isChatting = false;
  List<FlashCard> generatedFlashcards = [];

  List<DocumentModel> get allDocuments => _documents;
  String? get selectedSubject => _selectedSubject;
  DocumentType? get selectedType => _selectedType;
  bool get favoritesOnly => _favoritesOnly;
  String get selectedFolder => _selectedFolder;
  SortOption get sortBy => _sortBy;
  String get searchQuery => _searchQuery;

  List<File> get rawPages => _rawPages;
  List<File> get processedPages => _processedPages;
  int get previewIndex => _previewIndex;
  ScanFilter get selectedFilter => _selectedFilter;
  PdfPageSize get selectedPageSize => _selectedPageSize;

  List<String> get allFolders => [
        'All',
        ..._documents.map((d) => d.folder).toSet().toList()..sort(),
      ];

  List<String> get allSubjects => _documents
      .map((d) => d.subjectTag)
      .whereType<String>()
      .toSet()
      .toList()
    ..sort();

  List<DocumentModel> get filteredDocuments => _applyFilters();

  Stream<List<DocumentModel>> watchAllDocuments() =>
      repository.watchAllDocuments();

  Stream<List<DocumentModel>> watchBySubject(String subject) =>
      repository.watchBySubject(subject);

  Stream<List<DocumentModel>> watchByFolder(String folder) =>
      repository.watchByFolder(folder);

  int get totalDocuments => _documents.length;
  int get totalPdfs =>
      _documents.where((d) => d.type == DocumentType.pdf).length;
  int get totalScanned =>
      _documents.where((d) => d.source == DocumentSource.scanned).length;
  double get totalStorageMB =>
      _documents.fold<double>(0, (sum, d) => sum + d.fileSizeBytes) /
      (1024 * 1024);

  Future<void> scanDocument(BuildContext context) async {
    context.push('/documents/scanner');
  }

  Future<void> importFromGallery() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 90);
    _scannedPages = images.map((x) => File(x.path)).toList();
    notifyListeners();
  }

  Future<void> importPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final stat = await file.stat();
      final docId = DateTime.now().microsecondsSinceEpoch.toString();
      final model = DocumentModel(
        id: docId,
        userId: repository.userId,
        title: result.files.single.name.replaceAll('.pdf', ''),
        type: DocumentType.pdf,
        source: DocumentSource.imported,
        localPath: file.path,
        fileSizeBytes: stat.size,
        pageCount: 1,
        createdAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
      );
      await repository.saveDocument(model, file);
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Could not import PDF right now. ${e.toString()}';
    }
    notifyListeners();
  }

  Future<void> addScannedPage(File page) async {
    _scannedPages.add(page);
    notifyListeners();
  }

  Future<void> removeScannedPage(int index) async {
    if (index < 0 || index >= _scannedPages.length) return;
    _scannedPages.removeAt(index);
    notifyListeners();
  }

  void reorderPages(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final page = _scannedPages.removeAt(oldIndex);
    _scannedPages.insert(newIndex, page);
    notifyListeners();
  }

  /// Switches the filter on a page and re-processes it.
  /// Routes to the CamScanner-like flow (rawPages/processedPages) when active,
  /// and falls back to the legacy scannedPages flow otherwise.
  Future<void> applyFilterToPage(int pageIndex, ScanFilter filter) async {
    if (_rawPages.isNotEmpty &&
        pageIndex >= 0 &&
        pageIndex < _rawPages.length) {
      _selectedFilter = filter;
      final processed =
          await ScannerService.applyFilter(_rawPages[pageIndex], filter);
      if (pageIndex < _processedPages.length) {
        _processedPages[pageIndex] = processed;
      } else {
        while (_processedPages.length < pageIndex) {
          _processedPages.add(_rawPages[_processedPages.length]);
        }
        _processedPages.add(processed);
      }
      notifyListeners();
      return;
    }

    if (pageIndex < 0 || pageIndex >= _scannedPages.length) return;
    final file = _scannedPages[pageIndex];
    _scannedPages[pageIndex] = await ScannerService.applyFilter(file, filter);
    notifyListeners();
  }

  // ─── Scanning workflow (CamScanner-like flow) ────────────────────────────

  void setPreviewIndex(int index) {
    if (index < 0 || index >= _processedPages.length) return;
    _previewIndex = index;
    notifyListeners();
  }

  void setPageSize(PdfPageSize size) {
    _selectedPageSize = size;
    notifyListeners();
  }

  /// Replaces a single processed page (e.g. after manual crop) and notifies.
  void updateProcessedPage(int index, File file) {
    if (index < 0 || index >= _processedPages.length) return;
    _processedPages[index] = file;
    notifyListeners();
  }

  Future<List<File>> _processRawScanPages(
    List<File> pages, {
    bool append = false,
  }) async {
    if (!append) {
      _rawPages = List<File>.from(pages);
      _selectedFilter = ScanFilter.auto;
      _previewIndex = 0;
      ocrText = null;
    } else {
      _rawPages.addAll(pages);
    }

    final start = append ? _processedPages.length : 0;
    final total = _rawPages.length;
    final newlyProcessed = <File>[];

    for (var i = start; i < total; i++) {
      final rawPage = _rawPages[i];
      // Apply on the main isolate — applyFilter uses path_provider, which fails
      // inside compute() secondary isolates and blocked navigation to the editor.
      final processed =
          await ScannerService.applyFilter(rawPage, ScanFilter.auto);
      newlyProcessed.add(processed);

      if ((i - start + 1) % 3 == 0 || i == total - 1) {
        scanProgress = (i + 1) / total;
        notifyListeners();
      }
    }

    if (append) {
      _processedPages.addAll(newlyProcessed);
    } else {
      _processedPages = newlyProcessed;
    }
    return List<File>.from(_processedPages);
  }

  /// Scan more pages while already on the editor (does not open a new route).
  Future<void> appendScannedPages(BuildContext context) async {
    try {
      isScanProcessing = true;
      scanProgress = 0.0;
      notifyListeners();

      final pages = await ScannerService.scanWithEdgeDetection();
      if (pages.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new pages captured.')),
          );
        }
        return;
      }

      await _processRawScanPages(pages, append: true);
      _previewIndex = _processedPages.length - 1;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${pages.length} page${pages.length == 1 ? '' : 's'}',
            ),
          ),
        );
      }
    } catch (e) {
      errorMessage = 'Scan failed: $e';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      isScanProcessing = false;
      scanProgress = 0.0;
      notifyListeners();
    }
  }

  /// Seeds the scan session with externally captured pages (e.g. from the
  /// camera screen). Treats inputs as both raw and processed for simplicity —
  /// the editor can still re-apply filters and replace processed entries.
  void seedScanPages(List<File> pages, {bool notify = true}) {
    if (pages.isEmpty) return;
    _rawPages = List<File>.from(pages);
    _processedPages = List<File>.from(pages);
    _previewIndex = 0;
    ocrText = null;
    _selectedFilter = ScanFilter.auto;
    if (notify) notifyListeners();
  }

  /// Processes pages captured from the scanner route (new DocumentsScope).
  Future<void> processInitialPages(List<File> pages) async {
    if (pages.isEmpty) return;
    try {
      isScanProcessing = true;
      scanProgress = 0.0;
      notifyListeners();
      await _processRawScanPages(pages);
    } catch (e) {
      errorMessage = 'Failed to prepare document: $e';
      rethrow;
    } finally {
      isScanProcessing = false;
      scanProgress = 0.0;
      notifyListeners();
    }
  }

  /// Launches edge-detection scan, then opens the editor which shows a
  /// preparing loader while filters are applied.
  Future<void> startEdgeScan(BuildContext context) async {
    try {
      final pages = await ScannerService.scanWithEdgeDetection();
      if (pages.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pages captured. Try again or import from gallery.'),
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        context.push(
          '/documents/scanner-editor',
          extra: {
            'pages': List<File>.from(pages),
            'processOnLoad': true,
          },
        );
      }
    } catch (e) {
      errorMessage = 'Scan failed: $e';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
  }

  /// Rotates a page in _processedPages by [degrees] (positive = clockwise).
  Future<void> rotatePage(int pageIndex, int degrees) async {
    if (pageIndex < 0 || pageIndex >= _processedPages.length) return;
    final rotated = await ScannerService.rotatePage(
      _processedPages[pageIndex],
      degrees,
    );
    _processedPages[pageIndex] = rotated;
    notifyListeners();
  }

  /// Removes a page from both _rawPages and _processedPages.
  void deletePage(int pageIndex) {
    if (pageIndex < 0) return;
    if (pageIndex < _rawPages.length) _rawPages.removeAt(pageIndex);
    if (pageIndex < _processedPages.length) {
      _processedPages.removeAt(pageIndex);
    }
    if (_processedPages.isEmpty) {
      _previewIndex = 0;
    } else if (_previewIndex >= _processedPages.length) {
      _previewIndex = _processedPages.length - 1;
    }
    notifyListeners();
  }

  /// Reorders pages via drag-and-drop, keeping rawPages and processedPages
  /// aligned.
  void reorderPage(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex >= 0 && oldIndex < _rawPages.length) {
      final raw = _rawPages.removeAt(oldIndex);
      _rawPages.insert(newIndex.clamp(0, _rawPages.length), raw);
    }
    if (oldIndex >= 0 && oldIndex < _processedPages.length) {
      final p = _processedPages.removeAt(oldIndex);
      _processedPages.insert(newIndex.clamp(0, _processedPages.length), p);
    }
    notifyListeners();
  }

  /// Runs OCR on all _processedPages and stores the result in ocrText.
  Future<void> runOcr() async {
    if (_processedPages.isEmpty) return;
    isOcrRunning = true;
    notifyListeners();
    try {
      ocrText = await ScannerService.extractTextOcr(_processedPages);
    } catch (e) {
      errorMessage = 'OCR failed: $e';
      ocrText = '';
    } finally {
      isOcrRunning = false;
      notifyListeners();
    }
  }

  /// Saves the scan: builds PDF, generates thumbnail, runs OCR if needed,
  /// then persists via repository.saveScannedDocument and clears the session.
  Future<void> finalizeScan({
    required String title,
    required String folder,
    required String? subjectTag,
    required BuildContext context,
  }) async {
    if (_processedPages.isEmpty) return;
    isScanProcessing = true;
    scanProgress = 0.1;
    notifyListeners();
    try {
      final pdfFile = await ScannerService.pagesToPdf(
        _processedPages,
        title: title,
        pageSize: _selectedPageSize,
      );
      scanProgress = 0.3;
      notifyListeners();

      File? thumbnail;
      try {
        thumbnail =
            await ScannerService.generateThumbnail(_processedPages.first);
      } catch (_) {
        thumbnail = null;
      }
      scanProgress = 0.5;
      notifyListeners();

      if (ocrText == null) {
        isOcrRunning = true;
        notifyListeners();
        try {
          ocrText = await ScannerService.extractTextOcr(_processedPages);
        } catch (_) {
          ocrText = '';
        } finally {
          isOcrRunning = false;
        }
      }
      scanProgress = 0.7;
      notifyListeners();

      final docId = DateTime.now().microsecondsSinceEpoch.toString();
      final stat = await pdfFile.stat();
      final model = DocumentModel(
        id: docId,
        userId: repository.userId,
        title: title,
        subjectTag: subjectTag,
        type: DocumentType.scanned,
        source: DocumentSource.scanned,
        localPath: pdfFile.path,
        fileSizeBytes: stat.size,
        pageCount: _processedPages.length,
        folder: folder,
        createdAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
        extractedText:
            (ocrText == null || ocrText!.isEmpty) ? null : ocrText,
        hasOcrText: (ocrText ?? '').isNotEmpty,
        appliedFilter: _selectedFilter,
        pageSize: _selectedPageSize,
      );

      await repository.saveScannedDocument(
        doc: model,
        pdfFile: pdfFile,
        pageImages: _processedPages,
        thumbnail: thumbnail,
      );
      scanProgress = 0.9;
      notifyListeners();

      scanProgress = 1.0;
      notifyListeners();

      clearScanSession();
      isScanProcessing = false;
      notifyListeners();

      if (context.mounted) {
        context.go('/documents');
      }
    } catch (e) {
      errorMessage = 'Failed to save scan: $e';
      isScanProcessing = false;
      notifyListeners();
    }
  }

  /// Clears all scan session state.
  void clearScanSession() {
    _rawPages = [];
    _processedPages = [];
    _previewIndex = 0;
    ocrText = null;
    scanProgress = 0.0;
    notifyListeners();
  }

  Future<DocumentModel?> saveScannedDocument(
      String title, String? subject) async {
    if (_scannedPages.isEmpty) return null;
    isLoading = true;
    notifyListeners();
    try {
      final pdf = await ScannerService.pagesToPdf(
        _scannedPages,
        title: title,
        pageSize: PdfPageSize.a4,
      );
      final stat = await pdf.stat();
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final model = DocumentModel(
        id: id,
        userId: repository.userId,
        title: title,
        subjectTag: subject,
        type: DocumentType.scanned,
        source: DocumentSource.scanned,
        localPath: pdf.path,
        fileSizeBytes: stat.size,
        pageCount: _scannedPages.length,
        tags: const [],
        createdAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
      );
      final saved = await repository.saveDocument(model, pdf);
      _scannedPages = [];
      return saved;
    } catch (e) {
      errorMessage = e.toString();
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openDocument(DocumentModel doc, BuildContext context) async {
    await repository.updateLastOpened(doc.id);
    context.push(
      '/documents/pdf-viewer',
      extra: {'path': doc.localPath, 'title': doc.title, 'docId': doc.id},
    );
  }

  Future<void> deleteDocument(String docId) async {
    final doc = _documents.firstWhere(
      (d) => d.id == docId,
      orElse: () => throw StateError('Document $docId not found'),
    );
    await repository.deleteDocument(docId, doc.localPath);
  }

  Future<void> toggleFavorite(String docId) async {
    final doc = _documents.firstWhere((d) => d.id == docId);
    await repository.toggleFavorite(docId, !doc.isFavorite);
  }

  Future<void> shareDocument(DocumentModel doc) async {
    await Share.shareXFiles([XFile(doc.localPath)], text: doc.title);
  }

  Future<void> downloadDocument(DocumentModel doc) async {
    await OpenFilex.open(doc.localPath);
  }

  Future<void> analyzeDocument(DocumentModel doc) async {
    isAnalyzing = true;
    notifyListeners();
    try {
      final extracted =
          doc.extractedText ?? await PdfService.extractText(doc.localPath);
      if (extracted.isNotEmpty && doc.extractedText == null) {
        await repository.saveExtractedText(doc.id, extracted);
      }
      currentAnalysis = await aiService.analyzeDocument(extracted);
      await repository.saveAiSummary(doc.id, currentAnalysis!.summary);
    } finally {
      isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<String> chatWithDocument(DocumentModel doc, String question) async {
    isChatting = true;
    notifyListeners();
    try {
      final extracted =
          doc.extractedText ?? await PdfService.extractText(doc.localPath);
      final answer =
          await aiService.chatWithDocument(extracted, question, chatHistory);
      chatHistory.add({'role': 'user', 'content': question});
      chatHistory.add({'role': 'assistant', 'content': answer});
      return answer;
    } finally {
      isChatting = false;
      notifyListeners();
    }
  }

  Future<void> generateFlashcards(DocumentModel doc) async {
    final extracted =
        doc.extractedText ?? await PdfService.extractText(doc.localPath);
    generatedFlashcards = await aiService.generateFlashcards(extracted);
    notifyListeners();
  }

  Future<void> createTasksFromDocument(
      DocumentModel doc, BuildContext context) async {
    if (currentAnalysis == null) return;
    final taskRepository = TaskRepository();
    int created = 0;
    for (final suggested in currentAnalysis!.suggestedTasks) {
      final priority = _mapPriority(suggested.priority);
      final type = _mapTaskType(suggested.type);
      final task = TaskModel(
        id: '',
        userId: taskRepository.currentUserId,
        title: suggested.title,
        subject: doc.subjectTag ?? 'General',
        type: type,
        priority: priority,
        dueDate: DateTime.now().add(const Duration(days: 3)),
        status: TaskStatus.pending,
        createdAt: DateTime.now(),
      );
      await taskRepository.addTask(task);
      created++;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$created tasks created')),
    );
  }

  TaskPriority _mapPriority(String value) {
    switch (value.toLowerCase()) {
      case 'critical':
        return TaskPriority.critical;
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      case 'medium':
      default:
        return TaskPriority.medium;
    }
  }

  TaskType _mapTaskType(String value) {
    switch (value.toLowerCase()) {
      case 'assignment':
        return TaskType.assignment;
      case 'quiz':
        return TaskType.quiz;
      case 'project':
        return TaskType.project;
      case 'homework':
        return TaskType.homework;
      case 'exam':
        return TaskType.exam;
      case 'lab':
        return TaskType.lab;
      case 'presentation':
        return TaskType.presentation;
      default:
        return TaskType.other;
    }
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setSubjectFilter(String? subject) {
    _selectedSubject = subject;
    notifyListeners();
  }

  void setTypeFilter(DocumentType? type) {
    _selectedType = type;
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    _favoritesOnly = value;
    notifyListeners();
  }

  void setFolder(String folder) {
    _selectedFolder = folder;
    notifyListeners();
  }

  Future<void> moveDocumentToFolder(DocumentModel doc, String folder) async {
    await repository.updateDocument(doc.copyWith(folder: folder));
  }

  void setSortOption(SortOption option) {
    _sortBy = option;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedSubject = null;
    _selectedType = null;
    _favoritesOnly = false;
    _selectedFolder = 'All';
    _sortBy = SortOption.lastOpened;
    notifyListeners();
  }

  List<DocumentModel> _applyFilters() {
    var items = [..._documents];
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where(
            (d) =>
                d.title.toLowerCase().contains(q) ||
                d.tags.any((t) => t.toLowerCase().contains(q)) ||
                (d.extractedText ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    if (_selectedSubject != null) {
      items = items.where((d) => d.subjectTag == _selectedSubject).toList();
    }
    if (_selectedType != null) {
      items = items.where((d) => d.type == _selectedType).toList();
    }
    if (_favoritesOnly) {
      items = items.where((d) => d.isFavorite).toList();
    }
    if (_selectedFolder != 'All') {
      items = items.where((d) => d.folder == _selectedFolder).toList();
    }
    items.sort((a, b) {
      switch (_sortBy) {
        case SortOption.lastOpened:
          return b.lastOpenedAt.compareTo(a.lastOpenedAt);
        case SortOption.createdAt:
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.name:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case SortOption.size:
          return b.fileSizeBytes.compareTo(a.fileSizeBytes);
      }
    });
    return items;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
