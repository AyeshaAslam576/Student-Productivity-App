import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class LocalStorageService {
  static Future<String> get _docsPath async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/brainup_docs');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder.path;
  }

  static Future<String> get _imagesPath async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/brainup_images');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder.path;
  }

  /// Save a PDF or document file locally.
  /// Returns the local file path (stored in Firestore as metadata).
  static Future<String> saveDocument(File file, String fileName) async {
    final path = await _docsPath;
    final destination = File('$path/$fileName');
    await file.copy(destination.path);
    return destination.path;
  }

  /// Save a scanned page image locally.
  static Future<String> saveImage(File file, String fileName) async {
    final path = await _imagesPath;
    final destination = File('$path/$fileName');
    await file.copy(destination.path);
    return destination.path;
  }

  /// Save an image into a named subdirectory under brainup_images/
  /// (e.g. 'pages', 'thumbnails'). Creates the subdir if needed.
  static Future<String> saveImageInSubdir(
    File file,
    String fileName,
    String subdir,
  ) async {
    final basePath = await _imagesPath;
    final dir = Directory('$basePath/$subdir');
    if (!await dir.exists()) await dir.create(recursive: true);
    final destination = File('${dir.path}/$fileName');
    await file.copy(destination.path);
    return destination.path;
  }

  /// Delete a locally saved file.
  static Future<void> deleteFile(String localPath) async {
    final file = File(localPath);
    if (await file.exists()) await file.delete();
  }

  /// Check if a local file still exists.
  static Future<bool> fileExists(String localPath) async {
    return File(localPath).exists();
  }

  /// Get file size in bytes.
  static Future<int> getFileSize(String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) return 0;
    return await file.length();
  }

  /// Convert image to Base64 string for profile photos stored in Firestore.
  /// Compresses first to max 200×200 at quality 70 — keeps it tiny (~30-50 KB).
  static Future<String> imageToBase64(File imageFile) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 200,
      minHeight: 200,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    }
    return base64Encode(compressed);
  }

  /// Decode a Base64 string back to bytes.
  /// Use with Image.memory(LocalStorageService.base64ToBytes(b64)).
  static List<int> base64ToBytes(String base64String) {
    return base64Decode(base64String);
  }

  /// Clean up old documents older than [olderThanDays] days.
  static Future<void> cleanOldFiles({int olderThanDays = 60}) async {
    final path = await _docsPath;
    final dir = Directory(path);
    if (!await dir.exists()) return;

    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    await for (final entity in dir.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
    }
  }
}
