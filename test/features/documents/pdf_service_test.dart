import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:brainup/features/documents/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfService', () {
    test('generate, extract, page count, merge and split work', () async {
      final one = await PdfService.generateFromRichText(
        title: 'One',
        content: 'Operating Systems Assignment',
        author: 'BrainUp',
        theme: PdfTheme.academic,
      );
      final two = await PdfService.generateFromRichText(
        title: 'Two',
        content: 'Data Structures Quiz',
        author: 'BrainUp',
        theme: PdfTheme.clean,
      );

      final text = await PdfService.extractText(one.path);
      expect(text, contains('Operating'));
      expect(text, contains('Systems'));

      final pageCount = await PdfService.getPageCount(one.path);
      expect(pageCount, greaterThanOrEqualTo(1));

      final merged = await PdfService.mergePdfs([one.path, two.path]);
      final mergedCount = await PdfService.getPageCount(merged.path);
      expect(mergedCount, greaterThanOrEqualTo(2));

      final split = await PdfService.splitPdf(merged.path);
      expect(split, isNotEmpty);
      expect(await File(split.first.path).exists(), isTrue);

      final compressed = await PdfService.compressPdf(merged.path);
      expect(await compressed.exists(), isTrue);

      final watermarked = await PdfService.addWatermark(
        merged.path,
        watermarkText: 'BrainUp',
        opacity: 0.3,
      );
      expect(await watermarked.exists(), isTrue);
    });
  });
}
