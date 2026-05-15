import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/document_model.dart';
import '../../../core/services/local_storage_service.dart';

class DocumentRepository {
  final FirebaseFirestore _db;
  final String userId;

  DocumentRepository({
    required FirebaseFirestore db,
    required this.userId,
  }) : _db = db;

  CollectionReference<Map<String, dynamic>> get _docsRef =>
      _db.collection('users').doc(userId).collection('documents');

  // ─── SAVE ────────────────────────────────────────────────────────────────

  /// Copies [file] to local storage, stores metadata in Firestore.
  /// No cloud upload — Spark plan only.
  Future<DocumentModel> saveDocument(DocumentModel doc, File file) async {
    final ext = _extension(file.path);
    final fileName = '${doc.id}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final localPath = await LocalStorageService.saveDocument(file, fileName);
    final fileSize = await LocalStorageService.getFileSize(localPath);

    final updated = doc.copyWith(
      localPath: localPath,
      fileSizeBytes: fileSize,
    );
    await _docsRef.doc(updated.id).set(updated.toMap());
    return updated;
  }

  /// Saves multiple scanned page images alongside the PDF.
  /// PDF goes to brainup_docs/, page images to brainup_images/pages/,
  /// thumbnail to brainup_images/thumbnails/.
  Future<DocumentModel> saveScannedDocument({
    required DocumentModel doc,
    required File pdfFile,
    required List<File> pageImages,
    required File? thumbnail,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;

    final pdfName = '${doc.id}_$stamp${_extension(pdfFile.path)}';
    final pdfLocalPath =
        await LocalStorageService.saveDocument(pdfFile, pdfName);
    final pdfSize = await LocalStorageService.getFileSize(pdfLocalPath);

    final pageLocalPaths = <String>[];
    for (int i = 0; i < pageImages.length; i++) {
      final src = pageImages[i];
      final pageName =
          '${doc.id}_${stamp}_p${(i + 1).toString().padLeft(3, '0')}'
          '${_extension(src.path)}';
      final saved = await LocalStorageService.saveImageInSubdir(
        src,
        pageName,
        'pages',
      );
      pageLocalPaths.add(saved);
    }

    String? thumbLocalPath;
    if (thumbnail != null) {
      final thumbName = '${doc.id}_${stamp}_thumb${_extension(thumbnail.path)}';
      thumbLocalPath = await LocalStorageService.saveImageInSubdir(
        thumbnail,
        thumbName,
        'thumbnails',
      );
    }

    final updated = doc.copyWith(
      localPath: pdfLocalPath,
      pageImagePaths: pageLocalPaths,
      thumbnailPath: thumbLocalPath,
      fileSizeBytes: pdfSize,
      pageCount: pageImages.isNotEmpty ? pageImages.length : doc.pageCount,
    );
    await _docsRef.doc(updated.id).set(updated.toMap());
    return updated;
  }

  // ─── READ ────────────────────────────────────────────────────────────────

  Stream<List<DocumentModel>> watchAllDocuments() {
    return _docsRef.orderBy('lastOpenedAt', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => DocumentModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<DocumentModel>> watchBySubject(String subject) {
    return _docsRef
        .where('subjectTag', isEqualTo: subject)
        .orderBy('lastOpenedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DocumentModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<DocumentModel>> watchFavorites() {
    return _docsRef
        .where('isFavorite', isEqualTo: true)
        .orderBy('lastOpenedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DocumentModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Returns stream of documents in a specific folder.
  Stream<List<DocumentModel>> watchByFolder(String folder) {
    return _docsRef
        .where('folder', isEqualTo: folder)
        .orderBy('lastOpenedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DocumentModel.fromMap(d.id, d.data()))
            .toList());
  }

  // ─── UPDATE ──────────────────────────────────────────────────────────────

  Future<void> updateDocument(DocumentModel doc) async {
    await _docsRef.doc(doc.id).update(doc.toMap());
  }

  Future<void> updateLastOpened(String docId) async {
    await _docsRef.doc(docId).update({
      'lastOpenedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> toggleFavorite(String docId, bool value) async {
    await _docsRef.doc(docId).update({'isFavorite': value});
  }

  Future<void> saveAiSummary(String docId, String summary) async {
    await _docsRef.doc(docId).update({'aiSummary': summary});
  }

  Future<void> saveExtractedText(String docId, String text) async {
    await _docsRef.doc(docId).update({'extractedText': text});
  }

  /// Updates only the extractedText and hasOcrText fields in Firestore.
  Future<void> saveOcrText(String docId, String text) async {
    await _docsRef
        .doc(docId)
        .update({'extractedText': text, 'hasOcrText': true});
  }

  /// Updates the appliedFilter field for a document.
  Future<void> updateFilter(String docId, String filterName) async {
    await _docsRef.doc(docId).update({'appliedFilter': filterName});
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────

  Future<void> deleteDocument(String docId, String localPath) async {
    await LocalStorageService.deleteFile(localPath);
    await _docsRef.doc(docId).delete();
  }

  // ─── SEARCH ──────────────────────────────────────────────────────────────

  Future<List<DocumentModel>> searchDocuments(String query) async {
    final q = query.toLowerCase().trim();
    final all = await _docsRef.get();
    return all.docs
        .map((d) => DocumentModel.fromMap(d.id, d.data()))
        .where((doc) =>
            doc.title.toLowerCase().contains(q) ||
            doc.tags.any((tag) => tag.toLowerCase().contains(q)) ||
            (doc.extractedText ?? '').toLowerCase().contains(q))
        .toList();
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  String _extension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? '.${parts.last}' : '.pdf';
  }

  /// Convenience getter — used by viewmodel to access uid.
  static String get currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';
}
