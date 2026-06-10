import 'dart:io';

/// Route payload for [ScannerEditorScreen].
class ScannerEditorRouteArgs {
  final List<File> pages;
  final bool processOnLoad;

  const ScannerEditorRouteArgs({
    required this.pages,
    this.processOnLoad = false,
  });
}
