import 'dart:io';
import 'dart:math';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/app_colors.dart';

enum ScanFilter { auto, grayscale, blackAndWhite, original, enhance }

enum PdfPageSize { a4, letter, a3 }

class ScannerService {
  /// Uses cunning_document_scanner for real edge-detection scanning.
  /// Returns list of scanned image file paths (one per page).
  /// Google Play document scanner often returns `content://` URIs on Android.
  /// `File(path)` cannot read those — copy bytes into app temp storage first.
  static Future<File> _toReadableImageFile(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      throw Exception('Empty scan path');
    }

    final normalized = trimmed.startsWith('file://')
        ? trimmed.substring(7)
        : trimmed;

    if (!normalized.startsWith('content://')) {
      final file = File(normalized);
      if (await file.exists()) return file;
      throw Exception('Scan file not found: $normalized');
    }

    final bytes = await XFile(normalized).readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Scanned image was empty');
    }
    final tmp = await getTemporaryDirectory();
    final out = File(
      '${tmp.path}/scan_import_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(bytes);
    return out;
  }

  static Future<List<File>> scanWithEdgeDetection() async {
    try {
      final pictures = await CunningDocumentScanner.getPictures(
        noOfPages: 20,
        isGalleryImportAllowed: true,
      );
      if (pictures == null || pictures.isEmpty) return <File>[];

      final files = <File>[];
      for (final path in pictures) {
        files.add(await _toReadableImageFile(path));
      }
      return files;
    } catch (e) {
      throw Exception('Edge-detection scan failed: $e');
    }
  }

  /// Crops a single page using ImageCropper with AppColors theming.
  /// toolbarColor: AppColors.primary (0xFF0A2540 dark / 0xFF0B3D91 light)
  /// toolbarWidgetColor: AppColors.accent (0xFF00C2FF dark / 0xFF2D6CDF light)
  /// Returns the cropped File.
  static Future<File?> cropPage(File imageFile, BuildContext context) async {
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final toolbarColor = isDark ? AppColors.primary : AppColors.lightPrimary;
      final toolbarWidgetColor =
          isDark ? AppColors.accent : AppColors.lightAccent;
      final surfaceColor = isDark ? AppColors.surface : AppColors.lightSurface;

      const aspectRatios = <CropAspectRatioPreset>[
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio3x2,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9,
      ];

      final cropped = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Crop',
            toolbarColor: toolbarColor,
            toolbarWidgetColor: toolbarWidgetColor,
            statusBarColor: toolbarColor,
            backgroundColor: surfaceColor,
            activeControlsWidgetColor: toolbarWidgetColor,
            cropFrameColor: toolbarWidgetColor,
            cropGridColor: toolbarWidgetColor.withOpacity(0.4),
            dimmedLayerColor: Colors.black.withOpacity(0.6),
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
            showCropGrid: true,
            cropStyle: CropStyle.rectangle,
            aspectRatioPresets: aspectRatios,
          ),
          IOSUiSettings(
            title: 'Adjust Crop',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            aspectRatioPickerButtonHidden: false,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
            cropStyle: CropStyle.rectangle,
            aspectRatioPresets: aspectRatios,
          ),
        ],
      );
      if (cropped == null) return null;
      return File(cropped.path);
    } catch (e) {
      throw Exception('Cropping failed: $e');
    }
  }

  /// Runs Google ML Kit OCR on a list of image files.
  /// Returns concatenated text from all pages, separated by page breaks.
  static Future<String> extractTextOcr(List<File> pages) async {
    if (pages.isEmpty) return '';
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final buffer = StringBuffer();
    try {
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i];
        if (!await page.exists()) {
          throw Exception('OCR source missing: ${page.path}');
        }
        final input = InputImage.fromFile(page);
        final recognized = await recognizer.processImage(input);
        if (i > 0) buffer.writeln('\n--- Page ${i + 1} ---\n');
        buffer.write(recognized.text);
      }
      return buffer.toString().trim();
    } catch (e) {
      throw Exception('OCR text extraction failed: $e');
    } finally {
      await recognizer.close();
    }
  }

  /// Generates a JPEG thumbnail (300×400) from the first page.
  static Future<File> generateThumbnail(File firstPage) async {
    try {
      if (!await firstPage.exists()) {
        throw Exception('Thumbnail source missing: ${firstPage.path}');
      }
      final bytes = await firstPage.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Unable to decode image for thumbnail');
      }
      final resized = img.copyResize(
        decoded,
        width: 300,
        height: 400,
        interpolation: img.Interpolation.average,
      );
      final tmp = await getTemporaryDirectory();
      final outPath =
          '${tmp.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(resized, quality: 85));
      return outFile;
    } catch (e) {
      throw Exception('Thumbnail generation failed: $e');
    }
  }

  static Future<File> applyFilter(File imageFile, ScanFilter filter) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return imageFile;

    img.Image output = decoded;
    switch (filter) {
      case ScanFilter.auto:
      case ScanFilter.enhance:
        output = img.adjustColor(
          decoded,
          contrast: 1.2,
          saturation: 1.05,
          brightness: 1.05,
        );
        break;
      case ScanFilter.grayscale:
        output = img.grayscale(decoded);
        break;
      case ScanFilter.blackAndWhite:
        output = img.grayscale(decoded);
        output = img.contrast(output, contrast: 160);
        break;
      case ScanFilter.original:
        output = decoded;
        break;
    }

    final tmp = await getTemporaryDirectory();
    final outPath =
        '${tmp.path}/scan_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodeJpg(output, quality: 92));
    return compressForScan(outFile);
  }

  static Future<File> pagesToPdf(
    List<File> pages, {
    required String title,
    required PdfPageSize pageSize,
  }) async {
    final pdf = pw.Document(title: title);
    final format = switch (pageSize) {
      PdfPageSize.a4 => PdfPageFormat.a4,
      PdfPageSize.letter => PdfPageFormat.letter,
      PdfPageSize.a3 => PdfPageFormat.a3,
    };

    for (final page in pages) {
      final bytes = await page.readAsBytes();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(0),
          build: (_) => pw.Center(
            child: pw.FittedBox(
              fit: pw.BoxFit.contain,
              child: pw.Image(image),
            ),
          ),
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Rotates [imageFile] by [degrees] (positive = clockwise).
  static Future<File> rotatePage(File imageFile, int degrees) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return imageFile;
    final rotated = img.copyRotate(decoded, angle: degrees.toDouble());
    final tmp = await getTemporaryDirectory();
    final outPath =
        '${tmp.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodeJpg(rotated, quality: 92));
    return outFile;
  }

  static Future<File> compressForScan(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 88,
      minWidth: 2480,
      minHeight: 2480,
      keepExif: false,
    );
    return result != null ? File(result.path) : file;
  }
}
