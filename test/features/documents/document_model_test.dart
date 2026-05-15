import 'package:flutter_test/flutter_test.dart';

import 'package:brainup/features/documents/models/document_model.dart';

void main() {
  group('DocumentModel', () {
    test('formats file size correctly', () {
      final doc = DocumentModel(
        id: '1',
        userId: 'u',
        title: 'Doc',
        type: DocumentType.pdf,
        source: DocumentSource.imported,
        localPath: '/tmp/a.pdf',
        fileSizeBytes: 1536,
        pageCount: 1,
        createdAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
      );
      expect(doc.formattedSize, '1.5KB');
    });

    test('toMap excludes localPath by default', () {
      final doc = DocumentModel(
        id: '1',
        userId: 'u',
        title: 'Doc',
        type: DocumentType.pdf,
        source: DocumentSource.imported,
        localPath: '/tmp/a.pdf',
        fileSizeBytes: 100,
        pageCount: 1,
        createdAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
      );
      final map = doc.toMap();
      expect(map.containsKey('localPath'), isFalse);
    });
  });
}
