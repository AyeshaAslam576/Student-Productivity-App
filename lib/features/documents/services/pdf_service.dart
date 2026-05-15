import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import 'scanner_service.dart';

enum PdfTheme { clean, academic, dark, minimal }

class PdfService {
  static Future<String> extractText(String pdfPath) async {
    final bytes = await File(pdfPath).readAsBytes();
    final document = sfpdf.PdfDocument(inputBytes: bytes);
    try {
      final embeddedText =
          sfpdf.PdfTextExtractor(document).extractText().trim();
      if (embeddedText.isNotEmpty) {
        return embeddedText;
      }
    } finally {
      document.dispose();
    }
    return _extractTextViaOcr(bytes);
  }

  static Future<File> generateFromRichText({
    required String title,
    required String content,
    required String author,
    required PdfTheme theme,
  }) async {
    final doc = pw.Document(title: title, author: author);
    final style = switch (theme) {
      PdfTheme.clean => pw.TextStyle(fontSize: 12),
      PdfTheme.academic => pw.TextStyle(fontSize: 12, lineSpacing: 1.6),
      PdfTheme.dark => pw.TextStyle(fontSize: 12, color: PdfColors.white),
      PdfTheme.minimal => pw.TextStyle(fontSize: 11),
    };

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: theme == PdfTheme.dark
              ? (_) => pw.Container(color: PdfColor.fromHex('#101820'))
              : null,
        ),
        build: (_) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 20)),
          pw.SizedBox(height: 12),
          pw.Text('Author: $author', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 20),
          pw.Text(content, style: style),
        ],
      ),
    );

    final dir = await _getTempDir();
    final file = File('${dir.path}/${title.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  static Future<File> addWatermark(
    String pdfPath, {
    required String watermarkText,
    required double opacity,
  }) async {
    final bytes = await File(pdfPath).readAsBytes();
    final document = sfpdf.PdfDocument(inputBytes: bytes);
    final alpha = (opacity.clamp(0.1, 1.0) * 255).round();
    final brush = sfpdf.PdfSolidBrush(sfpdf.PdfColor(120, 120, 120, alpha));
    final font = sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.helvetica, 36);

    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final size = page.size;
      page.graphics.save();
      page.graphics.setTransparency(opacity.clamp(0.1, 1.0));
      page.graphics.translateTransform(size.width / 2, size.height / 2);
      page.graphics.rotateTransform(-35);
      page.graphics.drawString(
        watermarkText,
        font,
        brush: brush,
        bounds: const Rect.fromLTWH(-180, -20, 360, 60),
        format: sfpdf.PdfStringFormat(alignment: sfpdf.PdfTextAlignment.center),
      );
      page.graphics.restore();
    }

    final dir = await _getTempDir();
    final out = File(
      '${dir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await out.writeAsBytes(await document.save(), flush: true);
    document.dispose();
    return out;
  }

  static Future<File> mergePdfs(List<String> pdfPaths) async {
    if (pdfPaths.isEmpty) {
      throw ArgumentError('pdfPaths cannot be empty');
    }
    final target = sfpdf.PdfDocument();
    for (final path in pdfPaths) {
      final src = sfpdf.PdfDocument(inputBytes: await File(path).readAsBytes());
      for (int i = 0; i < src.pages.count; i++) {
        final page = src.pages[i];
        final newPage = target.pages.add();
        final template = page.createTemplate();
        newPage.graphics.drawPdfTemplate(template, Offset.zero);
      }
      src.dispose();
    }

    final dir = await _getTempDir();
    final out =
        File('${dir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await out.writeAsBytes(await target.save(), flush: true);
    target.dispose();
    return out;
  }

  static Future<List<File>> splitPdf(String pdfPath) async {
    final source =
        sfpdf.PdfDocument(inputBytes: await File(pdfPath).readAsBytes());
    final dir = await _getTempDir();
    final files = <File>[];
    for (int i = 0; i < source.pages.count; i++) {
      final pageDoc = sfpdf.PdfDocument();
      final page = source.pages[i];
      final newPage = pageDoc.pages.add();
      final template = page.createTemplate();
      newPage.graphics.drawPdfTemplate(template, Offset.zero);
      final f = File(
        '${dir.path}/split_${DateTime.now().millisecondsSinceEpoch}_p${i + 1}.pdf',
      );
      await f.writeAsBytes(await pageDoc.save(), flush: true);
      pageDoc.dispose();
      files.add(f);
    }
    source.dispose();
    return files;
  }

  static Future<File> protectPdf(String pdfPath, {required String password}) async {
    final doc = sfpdf.PdfDocument(inputBytes: await File(pdfPath).readAsBytes());
    doc.security.userPassword = password;
    doc.security.ownerPassword = '${password}_owner';
    doc.security.algorithm = sfpdf.PdfEncryptionAlgorithm.aesx256Bit;
    doc.security.permissions.addAll([
      sfpdf.PdfPermissionsFlags.print,
      sfpdf.PdfPermissionsFlags.copyContent,
    ]);
    final out = File(
      '${(await _getTempDir()).path}/protected_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await out.writeAsBytes(await doc.save(), flush: true);
    doc.dispose();
    return out;
  }

  static Future<File> compressPdf(String pdfPath) async {
    final doc =
        sfpdf.PdfDocument(inputBytes: await File(pdfPath).readAsBytes());
    doc.compressionLevel = sfpdf.PdfCompressionLevel.best;
    final out = File(
      '${(await _getTempDir()).path}/compressed_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await out.writeAsBytes(await doc.save(), flush: true);
    doc.dispose();
    return out;
  }

  static Future<File> imagesToPdf(
    List<File> images, {
    required String title,
    required PdfPageSize pageSize,
  }) async {
    return ScannerService.pagesToPdf(images, title: title, pageSize: pageSize);
  }

  static Future<int> getPageCount(String pdfPath) async {
    final doc =
        sfpdf.PdfDocument(inputBytes: await File(pdfPath).readAsBytes());
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }

  static Future<void> sharePdf(String pdfPath) async {
    await Share.shareXFiles([XFile(pdfPath)]);
  }

  static Future<void> printPdf(String pdfPath) async {
    final bytes = await File(pdfPath).readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> openPdf(String pdfPath) async {
    await OpenFilex.open(pdfPath);
  }

  static Future<Directory> _getTempDir() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  static Future<String> _extractTextViaOcr(Uint8List pdfBytes) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final out = StringBuffer();
    final dir = await _getTempDir();
    final tempPngPaths = <String>[];
    try {
      int pageIndex = 0;
      await for (final page in Printing.raster(pdfBytes, dpi: 180)) {
        if (pageIndex >= 10) break;
        final pngBytes = await page.toPng();
        final path =
            '${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}_$pageIndex.png';
        await File(path).writeAsBytes(pngBytes, flush: true);
        tempPngPaths.add(path);
        final input = InputImage.fromFilePath(path);
        final recognized = await recognizer.processImage(input);
        final text = recognized.text.trim();
        if (text.isNotEmpty) {
          if (out.isNotEmpty) out.writeln('\n---\n');
          out.write(text);
        }
        pageIndex++;
      }
      return out.toString().trim();
    } finally {
      await recognizer.close();
      for (final p in tempPngPaths) {
        final f = File(p);
        if (await f.exists()) {
          await f.delete();
        }
      }
    }
  }
}
