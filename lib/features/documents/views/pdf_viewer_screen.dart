import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../models/document_model.dart';
import '../services/pdf_service.dart';
import '../viewmodels/document_viewmodel.dart';

class PdfViewerScreen extends StatefulWidget {
  final String path;
  final String? title;
  final String? docId;
  final bool autoAnalyze;

  const PdfViewerScreen({
    super.key,
    required this.path,
    this.title,
    this.docId,
    this.autoAnalyze = false,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfControllerPinch _pdfController;
  int _currentPage = 1;
  int _pageCount = 0;
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.path),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  DocumentModel? _resolveDoc(DocumentViewModel vm) {
    if (widget.docId != null) {
      for (final d in vm.allDocuments) {
        if (d.id == widget.docId) return d;
      }
    }
    for (final d in vm.allDocuments) {
      if (d.localPath == widget.path) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocumentViewModel>();
    final doc = _resolveDoc(vm);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.primary.withOpacity(0.95),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          widget.title ?? doc?.title ?? 'Document',
          style: AppTextStyles.h5,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_rounded),
            onPressed: _share,
          ),
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_rounded),
            onPressed: _print,
          ),
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showMoreMenu(context, vm, doc),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _loadError != null
                ? _buildErrorState(_loadError!)
                : PdfViewPinch(
                    controller: _pdfController,
                    onDocumentLoaded: (document) {
                      if (!mounted) return;
                      setState(() {
                        _pageCount = document.pagesCount;
                        _isLoading = false;
                      });
                    },
                    onDocumentError: (error) {
                      if (!mounted) return;
                      setState(() {
                        _loadError = error;
                        _isLoading = false;
                      });
                    },
                    onPageChanged: (page) {
                      if (!mounted) return;
                      setState(() => _currentPage = page);
                    },
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                  ),
          ),
          if (_pageCount > 0)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: _PageIndicator(
                current: _currentPage,
                total: _pageCount,
              ),
            ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        doc: doc,
        pageCount: _pageCount,
        onShowOcr: () => _showOcrPanel(context, doc),
        onSummarize: () => _navigateToSummarizer(context, doc),
        onToggleFavorite: doc == null
            ? null
            : () => vm.toggleFavorite(doc.id),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not open PDF',
              style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top-bar actions ───────────────────────────────────────────────────────

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(
        [XFile(widget.path)],
        text: widget.title,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not share. $e')),
      );
    }
  }

  Future<void> _print() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(
        name: widget.title ?? 'Document',
        onLayout: (_) => File(widget.path).readAsBytes(),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not print. $e')),
      );
    }
  }

  // ─── More menu ─────────────────────────────────────────────────────────────

  void _showMoreMenu(
    BuildContext context,
    DocumentViewModel vm,
    DocumentModel? doc,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? doc?.title ?? 'Document',
                      style: AppTextStyles.h5,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceBorder, height: 1),
            _MenuTile(
              icon: Icons.image_rounded,
              label: 'Share as Image',
              iconColor: AppColors.warning,
              onTap: () {
                Navigator.pop(sheetCtx);
                if (doc != null) _shareAsImage(context, doc);
              },
            ),
            _MenuTile(
              icon: Icons.compress_rounded,
              label: 'Compress',
              onTap: () {
                Navigator.pop(sheetCtx);
                if (doc != null) _compressPdf(context, vm, doc);
              },
            ),
            _MenuTile(
              icon: Icons.call_split_rounded,
              label: 'Split into pages',
              iconColor: AppColors.error,
              onTap: () {
                Navigator.pop(sheetCtx);
                if (doc != null) _splitPdf(context, vm, doc);
              },
            ),
            _MenuTile(
              icon: Icons.merge_rounded,
              label: 'Merge with…',
              onTap: () {
                Navigator.pop(sheetCtx);
                if (doc != null) _mergePdfFlow(context, vm, doc);
              },
            ),
            _MenuTile(
              icon: Icons.lock_rounded,
              label: 'Password protect',
              iconColor: AppColors.warning,
              onTap: () {
                Navigator.pop(sheetCtx);
                if (doc != null) _lockPdf(context, vm, doc);
              },
            ),
            _MenuTile(
              icon: Icons.water_rounded,
              label: 'Add watermark',
              onTap: () {
                Navigator.pop(sheetCtx);
                if (doc != null) _addWatermark(context, vm, doc);
              },
            ),
            _MenuTile(
              icon: Icons.open_in_new_rounded,
              label: 'Open externally',
              onTap: () {
                Navigator.pop(sheetCtx);
                PdfService.openPdf(widget.path);
              },
            ),
            _MenuTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              iconColor: AppColors.error,
              labelColor: AppColors.error,
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (doc == null) return;
                final ok = await _confirmDelete(context, doc);
                if (!ok) return;
                await vm.deleteDocument(doc.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── OCR bottom sheet ──────────────────────────────────────────────────────

  void _showOcrPanel(BuildContext context, DocumentModel? doc) {
    final text = doc?.extractedText ?? '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text('Extracted Text', style: AppTextStyles.h4),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: text.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: text),
                            );
                            if (sheetCtx.mounted) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard'),
                                ),
                              );
                            }
                          },
                    icon: Icon(
                      Icons.copy_rounded,
                      color: text.isEmpty
                          ? AppColors.textSecondary
                          : AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: text.isEmpty
                    ? Center(
                        child: Text(
                          'No OCR text available for this document.',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : SingleChildScrollView(
                        controller: scrollController,
                        child: SelectableText(
                          text,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 12),
                BrainUpButton(
                  label: 'Summarize with AI',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    context.push('/ai/summarizer', extra: text);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSummarizer(BuildContext context, DocumentModel? doc) {
    final text = doc?.extractedText ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No extracted text for this document yet. Open the OCR panel first.',
          ),
        ),
      );
      return;
    }
    context.push('/ai/summarizer', extra: text);
  }

  Future<bool> _confirmDelete(BuildContext context, DocumentModel doc) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.error,
          size: 36,
        ),
        title: Text(
          'Delete document?',
          style: AppTextStyles.h4,
          textAlign: TextAlign.center,
        ),
        content: Text(
          '"${doc.title}" will be permanently removed.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Delete',
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ─── Power tools (preserved from previous viewer) ─────────────────────────

  void _showLoadingSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(msg),
        ]),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _shareAsImage(BuildContext context, DocumentModel doc) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      _showLoadingSnack(context, 'Converting to image…');
      final bytes = await File(doc.localPath).readAsBytes();
      await for (final page in Printing.raster(bytes, dpi: 200, pages: [0])) {
        final png = await page.toPng();
        final dir = await getTemporaryDirectory();
        final imgFile = File('${dir.path}/${doc.title}.png');
        await imgFile.writeAsBytes(png);
        await Share.shareXFiles(
          [XFile(imgFile.path)],
          text: doc.title,
        );
        break;
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not convert: $e')),
      );
    }
  }

  Future<void> _compressPdf(
    BuildContext context,
    DocumentViewModel vm,
    DocumentModel doc,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      _showLoadingSnack(context, 'Compressing PDF…');
      final compressed = await PdfService.compressPdf(doc.localPath);
      final oldSize = doc.fileSizeBytes;
      final newSize = await compressed.length();
      final saved = ((oldSize - newSize) / oldSize * 100).toStringAsFixed(1);

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: Text('Compressed!', style: AppTextStyles.h4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Before:', style: AppTextStyles.body),
                  Text(
                    doc.formattedSize,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('After:', style: AppTextStyles.body),
                  Text(
                    '${(newSize / 1024 / 1024).toStringAsFixed(1)} MB',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.success),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$saved% saved',
                style:
                    AppTextStyles.h5.copyWith(color: AppColors.accent),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final newDoc = doc.copyWith(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: '${doc.title} (Compressed)',
                  fileSizeBytes: newSize,
                );
                await vm.repository.saveDocument(newDoc, compressed);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Saved as new document!')),
                );
              },
              child: const Text(
                'Save',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Compression failed: $e')),
      );
    }
  }

  Future<void> _splitPdf(
    BuildContext context,
    DocumentViewModel vm,
    DocumentModel doc,
  ) async {
    if (doc.pageCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot split a single-page document')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Split PDF', style: AppTextStyles.h4),
        content: Text(
          'This will split "${doc.title}" into ${doc.pageCount} separate PDF files, one per page.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _showLoadingSnack(context, 'Splitting ${doc.pageCount} pages…');
              try {
                final files = await PdfService.splitPdf(doc.localPath);
                for (int i = 0; i < files.length; i++) {
                  final splitDoc = doc.copyWith(
                    id: DateTime.now().microsecondsSinceEpoch.toString() +
                        i.toString(),
                    title: '${doc.title} — Page ${i + 1}',
                    pageCount: 1,
                  );
                  await vm.repository.saveDocument(splitDoc, files[i]);
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Split into ${files.length} documents!'),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Split failed: $e')),
                );
              }
            },
            child: const Text(
              'Split',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mergePdfFlow(
    BuildContext context,
    DocumentViewModel vm,
    DocumentModel doc,
  ) async {
    final allDocs = vm.allDocuments
        .where((d) => d.id != doc.id && d.type == DocumentType.pdf)
        .toList();

    if (allDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other PDFs to merge with')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final selected = <String>{};

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const _SheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Select PDFs to merge with "${doc.title}"',
                style: AppTextStyles.h5,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: allDocs.length,
                  itemBuilder: (_, i) {
                    final d = allDocs[i];
                    return CheckboxListTile(
                      value: selected.contains(d.id),
                      onChanged: (v) => setSheetState(() {
                        if (v == true) {
                          selected.add(d.id);
                        } else {
                          selected.remove(d.id);
                        }
                      }),
                      title: Text(d.title, style: AppTextStyles.body),
                      subtitle: Text(
                        d.formattedSize,
                        style: AppTextStyles.caption,
                      ),
                      activeColor: AppColors.accent,
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: BrainUpButton(
                  label: 'Merge ${selected.length + 1} PDFs',
                  onTap: selected.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          _showLoadingSnack(context, 'Merging PDFs…');
                          try {
                            final paths = [
                              doc.localPath,
                              ...allDocs
                                  .where((d) => selected.contains(d.id))
                                  .map((d) => d.localPath),
                            ];
                            final merged =
                                await PdfService.mergePdfs(paths);
                            final mergedDoc = doc.copyWith(
                              id: DateTime.now()
                                  .microsecondsSinceEpoch
                                  .toString(),
                              title: '${doc.title} (Merged)',
                              pageCount:
                                  doc.pageCount + selected.length,
                            );
                            await vm.repository
                                .saveDocument(mergedDoc, merged);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Merged successfully!'),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Merge failed: $e')),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _lockPdf(
    BuildContext context,
    DocumentViewModel vm,
    DocumentModel doc,
  ) async {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.lock_rounded,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Text('Password protect PDF', style: AppTextStyles.h4),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Anyone opening this PDF will need this password.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                BrainUpTextField(
                  controller: passCtrl,
                  label: 'Set password',
                  obscureText: true,
                  validator: (v) =>
                      v == null || v.length < 4 ? 'Min 4 characters' : null,
                ),
                const SizedBox(height: 12),
                BrainUpTextField(
                  controller: confirmCtrl,
                  label: 'Confirm password',
                  obscureText: true,
                  validator: (v) => v != passCtrl.text
                      ? 'Passwords do not match'
                      : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: BrainUpButton(
                    label: 'Lock PDF',
                    onTap: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      _showLoadingSnack(context, 'Encrypting PDF…');
                      try {
                        final locked = await PdfService.protectPdf(
                          doc.localPath,
                          password: passCtrl.text,
                        );
                        final lockedDoc = doc.copyWith(
                          id: DateTime.now()
                              .microsecondsSinceEpoch
                              .toString(),
                          title: '${doc.title} (Protected)',
                        );
                        await vm.repository.saveDocument(lockedDoc, locked);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('PDF locked successfully!'),
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to lock: $e')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addWatermark(
    BuildContext context,
    DocumentViewModel vm,
    DocumentModel doc,
  ) async {
    final textCtrl = TextEditingController(text: 'CONFIDENTIAL');
    double opacity = 0.3;
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 16),
                Text('Add Watermark', style: AppTextStyles.h4),
                const SizedBox(height: 16),
                BrainUpTextField(
                  controller: textCtrl,
                  label: 'Watermark text',
                ),
                const SizedBox(height: 16),
                Text(
                  'Opacity: ${(opacity * 100).round()}%',
                  style: AppTextStyles.bodySmall,
                ),
                Slider(
                  value: opacity,
                  min: 0.1,
                  max: 0.8,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setSheetState(() => opacity = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: BrainUpButton(
                    label: 'Apply Watermark',
                    onTap: () async {
                      Navigator.pop(ctx);
                      _showLoadingSnack(context, 'Adding watermark…');
                      try {
                        final out = await PdfService.addWatermark(
                          doc.localPath,
                          watermarkText: textCtrl.text.trim().isEmpty
                              ? 'CONFIDENTIAL'
                              : textCtrl.text.trim(),
                          opacity: opacity,
                        );
                        final wDoc = doc.copyWith(
                          id: DateTime.now()
                              .microsecondsSinceEpoch
                              .toString(),
                          title: '${doc.title} (Watermarked)',
                        );
                        await vm.repository.saveDocument(wDoc, out);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Watermark added!'),
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Page indicator ──────────────────────────────────────────────────────────

class _PageIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _PageIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Text(
            '$current / $total',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom bar ──────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final DocumentModel? doc;
  final int pageCount;
  final VoidCallback onShowOcr;
  final VoidCallback onSummarize;
  final VoidCallback? onToggleFavorite;

  const _BottomBar({
    required this.doc,
    required this.pageCount,
    required this.onShowOcr,
    required this.onSummarize,
    required this.onToggleFavorite,
  });

  String get _statusLabel {
    final pages = pageCount > 0
        ? pageCount
        : (doc?.pageCount ?? 0);
    final size = doc?.formattedSize;
    if (pages > 0 && size != null) return '$pages pages · $size';
    if (pages > 0) return '$pages pages';
    if (size != null) return size;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: AppColors.surfaceCard,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Extracted text',
              icon: const Icon(
                Icons.text_fields_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: onShowOcr,
            ),
            IconButton(
              tooltip: 'Summarize with AI',
              icon: const Icon(
                Icons.psychology_rounded,
                color: AppColors.info,
              ),
              onPressed: onSummarize,
            ),
            const Spacer(),
            Flexible(
              child: Text(
                _statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: doc?.isFavorite == true
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              icon: Icon(
                doc?.isFavorite == true
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: doc?.isFavorite == true
                    ? AppColors.warning
                    : AppColors.textSecondary,
              ),
              onPressed: onToggleFavorite,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Menu helpers ────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(
        label,
        style: AppTextStyles.body.copyWith(
          color: labelColor ?? AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.surfaceBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
