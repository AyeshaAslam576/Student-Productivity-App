import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../services/scanner_service.dart';
import '../viewmodels/document_viewmodel.dart';

class ScannerEditorScreen extends StatefulWidget {
  final List<File>? initialPages;
  const ScannerEditorScreen({super.key, this.initialPages});

  @override
  State<ScannerEditorScreen> createState() => _ScannerEditorScreenState();
}

class _ScannerEditorScreenState extends State<ScannerEditorScreen> {
  bool _isCropping = false;
  bool _didSeedFromRoute = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSeedFromRoute) return;
    _didSeedFromRoute = true;
    final initial = widget.initialPages;
    if (initial != null && initial.isNotEmpty) {
      // Seed synchronously so the first build already has pages
      context.read<DocumentViewModel>().seedScanPages(initial);
    }
  }

  List<File> _effectivePages(DocumentViewModel vm) {
    if (vm.processedPages.isNotEmpty) return vm.processedPages;
    final initial = widget.initialPages;
    if (initial != null && initial.isNotEmpty) return initial;
    return const [];
  }

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _surface(BuildContext c) =>
      _isDark(c) ? AppColors.surface : AppColors.lightSurface;
  Color _surfaceCard(BuildContext c) =>
      _isDark(c) ? AppColors.surfaceCard : AppColors.lightSurfaceCard;
  Color _surfaceBorder(BuildContext c) =>
      _isDark(c) ? AppColors.surfaceBorder : AppColors.lightSurfaceBorder;
  Color _accent(BuildContext c) =>
      _isDark(c) ? AppColors.accent : AppColors.lightAccent;
  Color _textSecondary(BuildContext c) =>
      _isDark(c) ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color _textPrimary(BuildContext c) =>
      _isDark(c) ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color _error(BuildContext c) =>
      _isDark(c) ? AppColors.error : AppColors.lightError;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocumentViewModel>();
    final pages = _effectivePages(vm);
    final index = pages.isEmpty
        ? 0
        : vm.previewIndex.clamp(0, pages.length - 1);

    if (vm.isScanProcessing && pages.isEmpty) {
      return Scaffold(
        backgroundColor: _surface(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _accent(context)),
              const SizedBox(height: 16),
              Text(
                'Processing scan…',
                style: AppTextStyles.body.copyWith(color: _textSecondary(context)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surface(context),
      body: SafeArea(
        child: pages.isEmpty && !vm.isScanProcessing
            ? _buildEmpty(context)
            : pages.isEmpty && vm.isScanProcessing
                ? const SizedBox.shrink()
                : Column(
                children: [
                  _TopBar(
                    onBack: () => context.pop(),
                    onAddPage: () => _addPage(context),
                    onDone: () => _showSaveDialog(context),
                    textSecondary: _textSecondary(context),
                    textPrimary: _textPrimary(context),
                    accent: _accent(context),
                  ),
                  Expanded(
                    child: _PagePreview(
                      page: pages[index],
                      currentIndex: index,
                      totalPages: pages.length,
                      isProcessing: vm.isScanProcessing || _isCropping,
                      progress: vm.scanProgress,
                      surfaceCard: _surfaceCard(context),
                      surfaceBorder: _surfaceBorder(context),
                      accent: _accent(context),
                      textPrimary: _textPrimary(context),
                    ),
                  ),
                  _FilterBar(
                    page: pages[index],
                    selectedFilter: vm.selectedFilter,
                    onSelect: (f) async {
                      await vm.applyFilterToPage(index, f);
                    },
                    surfaceCard: _surfaceCard(context),
                    surfaceBorder: _surfaceBorder(context),
                    accent: _accent(context),
                    textSecondary: _textSecondary(context),
                    textPrimary: _textPrimary(context),
                  ),
                  _PageStrip(
                    pages: pages,
                    currentIndex: index,
                    onSelect: vm.setPreviewIndex,
                    onReorder: vm.reorderPage,
                    accent: _accent(context),
                    surfaceBorder: _surfaceBorder(context),
                  ),
                  _ActionBar(
                    onRotateLeft: () => vm.rotatePage(index, -90),
                    onRotateRight: () => vm.rotatePage(index, 90),
                    onCrop: () => _cropCurrentPage(context, index),
                    onDelete: () => _confirmDelete(context, index),
                    onOcr: () => _runOcrAndShow(context),
                    isOcrRunning: vm.isOcrRunning,
                    textSecondary: _textSecondary(context),
                    accent: _accent(context),
                    error: _error(context),
                    surfaceCard: _surfaceCard(context),
                    surfaceBorder: _surfaceBorder(context),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 64,
              color: _textSecondary(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No pages to edit',
              style: AppTextStyles.h4.copyWith(color: _textPrimary(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Capture or import pages first to start editing.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: _textSecondary(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            BrainUpButton(
              label: 'Back',
              width: 160,
              onTap: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPage(BuildContext context) async {
    final vm = context.read<DocumentViewModel>();
    await vm.appendScannedPages(context);
  }

  Future<void> _cropCurrentPage(BuildContext context, int index) async {
    final vm = context.read<DocumentViewModel>();
    if (index < 0 || index >= vm.processedPages.length) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isCropping = true);
    try {
      final cropped =
          await ScannerService.cropPage(vm.processedPages[index], context);
      if (cropped != null) {
        vm.updateProcessedPage(index, cropped);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not crop page. $e')),
      );
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final vm = context.read<DocumentViewModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceCard(context),
        title: Text(
          'Delete page?',
          style: AppTextStyles.h4.copyWith(color: _textPrimary(context)),
        ),
        content: Text(
          'Page ${index + 1} will be removed from this scan.',
          style: AppTextStyles.body.copyWith(color: _textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body
                  .copyWith(color: _textSecondary(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: AppTextStyles.body.copyWith(color: _error(context)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      vm.deletePage(index);
    }
  }

  Future<void> _runOcrAndShow(BuildContext context) async {
    final vm = context.read<DocumentViewModel>();
    if (vm.processedPages.isEmpty) return;
    if (vm.ocrText == null || vm.ocrText!.isEmpty) {
      await vm.runOcr();
    }
    if (!context.mounted) return;
    await _showOcrBottomSheet(context);
  }

  Future<void> _showOcrBottomSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OcrBottomSheet(
        surfaceCard: _surfaceCard(context),
        surfaceBorder: _surfaceBorder(context),
        textPrimary: _textPrimary(context),
        textSecondary: _textSecondary(context),
        accent: _accent(context),
      ),
    );
  }

  Future<void> _showSaveDialog(BuildContext context) async {
    final vm = context.read<DocumentViewModel>();
    final pages = _effectivePages(vm);
    if (pages.isEmpty) return;

    final defaultTitle =
        'My Scan — ${DateFormat.yMMMd().format(DateTime.now())}';
    final titleCtrl = TextEditingController(text: defaultTitle);

    final folders = vm.allFolders.where((f) => f != 'All').toList();
    if (folders.isEmpty) folders.add('General');
    String selectedFolder = folders.first;

    final subjects = vm.allSubjects;
    String? selectedSubject;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final pageSize = vm.selectedPageSize;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: _surfaceCard(context),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusXl),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _surfaceBorder(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Save Document',
                      style: AppTextStyles.h4
                          .copyWith(color: _textPrimary(context)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    BrainUpTextField(
                      label: 'Title',
                      controller: titleCtrl,
                      hint: defaultTitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildDropdownField<String>(
                      context: context,
                      label: 'Folder',
                      value: selectedFolder,
                      items: folders,
                      itemLabel: (s) => s,
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() => selectedFolder = v);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildDropdownField<String?>(
                      context: context,
                      label: 'Subject (optional)',
                      value: selectedSubject,
                      items: <String?>[null, ...subjects],
                      itemLabel: (s) => s ?? 'None',
                      onChanged: (v) {
                        setSheetState(() => selectedSubject = v);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Page Size',
                      style: AppTextStyles.label
                          .copyWith(color: _textSecondary(context)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        for (final size in PdfPageSize.values)
                          Padding(
                            padding:
                                const EdgeInsets.only(right: AppSpacing.sm),
                            child: _PageSizeChip(
                              label: _pageSizeLabel(size),
                              selected: pageSize == size,
                              onTap: () {
                                vm.setPageSize(size);
                                setSheetState(() {});
                              },
                              accent: _accent(context),
                              surfaceCard: _surfaceCard(context),
                              surfaceBorder: _surfaceBorder(context),
                              textPrimary: _textPrimary(context),
                              textSecondary: _textSecondary(context),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    BrainUpButton(
                      label: 'Save as PDF',
                      isLoading: vm.isScanProcessing,
                      onTap: () async {
                        final title = titleCtrl.text.trim().isEmpty
                            ? defaultTitle
                            : titleCtrl.text.trim();
                        Navigator.pop(sheetCtx);
                        await vm.finalizeScan(
                          title: title,
                          folder: selectedFolder,
                          subjectTag: selectedSubject,
                          context: context,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    BrainUpButton.secondary(
                      label: 'Save as Images',
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await _shareAsImages(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _shareAsImages(BuildContext context) async {
    final vm = context.read<DocumentViewModel>();
    if (vm.processedPages.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(
        vm.processedPages.map((f) => XFile(f.path)).toList(),
        text: 'Scanned pages',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not share images. $e')),
      );
    }
  }

  String _pageSizeLabel(PdfPageSize size) {
    switch (size) {
      case PdfPageSize.a4:
        return 'A4';
      case PdfPageSize.letter:
        return 'Letter';
      case PdfPageSize.a3:
        return 'A3';
    }
  }

  Widget _buildDropdownField<T>({
    required BuildContext context,
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      dropdownColor: _surfaceCard(context),
      style: AppTextStyles.body.copyWith(color: _textPrimary(context)),
      iconEnabledColor: _textSecondary(context),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            AppTextStyles.label.copyWith(color: _textSecondary(context)),
        filled: true,
        fillColor: _surfaceCard(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: _surfaceBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: _surfaceBorder(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: _accent(context), width: 1.5),
        ),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(itemLabel(e)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ─── TOP BAR ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onAddPage;
  final VoidCallback onDone;
  final Color textSecondary;
  final Color textPrimary;
  final Color accent;

  const _TopBar({
    required this.onBack,
    required this.onAddPage,
    required this.onDone,
    required this.textSecondary,
    required this.textPrimary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: textSecondary,
            ),
            tooltip: 'Back',
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Edit Scan',
              style: AppTextStyles.h4.copyWith(color: textPrimary),
            ),
          ),
          IconButton(
            onPressed: onAddPage,
            icon: Icon(
              Icons.add_photo_alternate_rounded,
              color: accent,
            ),
            tooltip: 'Add page',
          ),
          const SizedBox(width: AppSpacing.sm),
          BrainUpButton.small(
            label: 'Done',
            onTap: onDone,
          ),
        ],
      ),
    );
  }
}

// ─── PAGE PREVIEW ────────────────────────────────────────────────────────────

class _PagePreview extends StatelessWidget {
  final File page;
  final int currentIndex;
  final int totalPages;
  final bool isProcessing;
  final double progress;
  final Color surfaceCard;
  final Color surfaceBorder;
  final Color accent;
  final Color textPrimary;

  const _PagePreview({
    required this.page,
    required this.currentIndex,
    required this.totalPages,
    required this.isProcessing,
    required this.progress,
    required this.surfaceCard,
    required this.surfaceBorder,
    required this.accent,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.file(
                  page,
                  key: ValueKey('${page.path}-${page.lengthSync()}'),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: surfaceCard.withOpacity(0.8),
                borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                border: Border.all(color: surfaceBorder),
              ),
              child: Text(
                '${currentIndex + 1} / $totalPages',
                style: AppTextStyles.labelSmall.copyWith(color: textPrimary),
              ),
            ),
          ),
          if (isProcessing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppSpacing.radiusLg),
                ),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  color: accent,
                  backgroundColor: surfaceBorder,
                  minHeight: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── FILTER BAR ──────────────────────────────────────────────────────────────

const List<_FilterOption> _filterOptions = [
  _FilterOption(ScanFilter.auto, 'Auto'),
  _FilterOption(ScanFilter.blackAndWhite, 'B&W'),
  _FilterOption(ScanFilter.grayscale, 'Grayscale'),
  _FilterOption(ScanFilter.enhance, 'Enhance'),
  _FilterOption(ScanFilter.original, 'Original'),
];

class _FilterOption {
  final ScanFilter filter;
  final String label;
  const _FilterOption(this.filter, this.label);
}

class _FilterBar extends StatelessWidget {
  final File page;
  final ScanFilter selectedFilter;
  final ValueChanged<ScanFilter> onSelect;
  final Color surfaceCard;
  final Color surfaceBorder;
  final Color accent;
  final Color textSecondary;
  final Color textPrimary;

  const _FilterBar({
    required this.page,
    required this.selectedFilter,
    required this.onSelect,
    required this.surfaceCard,
    required this.surfaceBorder,
    required this.accent,
    required this.textSecondary,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        itemBuilder: (_, i) {
          final opt = _filterOptions[i];
          final isSelected = opt.filter == selectedFilter;
          return GestureDetector(
            onTap: () => onSelect(opt.filter),
            child: Container(
              width: 74,
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withOpacity(0.18)
                    : surfaceCard,
                border: Border.all(
                  color: isSelected ? accent : surfaceBorder,
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FilterThumbnail(page: page),
                  const SizedBox(height: 6),
                  Text(
                    opt.label,
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected ? accent : textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemCount: _filterOptions.length,
      ),
    );
  }
}

class _FilterThumbnail extends StatelessWidget {
  final File page;
  const _FilterThumbnail({required this.page});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Image.file(
        page,
        width: 50,
        height: 65,
        fit: BoxFit.cover,
        cacheWidth: 100,
      ),
    );
  }
}

// ─── PAGE STRIP ──────────────────────────────────────────────────────────────

class _PageStrip extends StatelessWidget {
  final List<File> pages;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Color accent;
  final Color surfaceBorder;

  const _PageStrip({
    required this.pages,
    required this.currentIndex,
    required this.onSelect,
    required this.onReorder,
    required this.accent,
    required this.surfaceBorder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, _, __) => Material(
          color: Colors.transparent,
          child: Transform.scale(scale: 1.05, child: child),
        ),
        itemCount: pages.length,
        onReorder: onReorder,
        itemBuilder: (_, i) {
          final isSelected = i == currentIndex;
          return ReorderableDragStartListener(
            key: ValueKey('strip-${pages[i].path}'),
            index: i,
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? accent : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    pages[i],
                    width: 60,
                    height: 80,
                    fit: BoxFit.cover,
                    cacheWidth: 120,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── ACTION BAR ──────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onCrop;
  final VoidCallback onDelete;
  final VoidCallback onOcr;
  final bool isOcrRunning;
  final Color textSecondary;
  final Color accent;
  final Color error;
  final Color surfaceCard;
  final Color surfaceBorder;

  const _ActionBar({
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onCrop,
    required this.onDelete,
    required this.onOcr,
    required this.isOcrRunning,
    required this.textSecondary,
    required this.accent,
    required this.error,
    required this.surfaceCard,
    required this.surfaceBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: surfaceCard,
        border: Border(
          top: BorderSide(color: surfaceBorder),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionIcon(
            icon: Icons.rotate_left_rounded,
            label: 'Rotate L',
            onTap: onRotateLeft,
            color: textSecondary,
          ),
          _ActionIcon(
            icon: Icons.rotate_right_rounded,
            label: 'Rotate R',
            onTap: onRotateRight,
            color: textSecondary,
          ),
          _ActionIcon(
            icon: Icons.crop_rounded,
            label: 'Crop',
            onTap: onCrop,
            color: textSecondary,
          ),
          _ActionIcon(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            onTap: onDelete,
            color: error,
          ),
          _ActionIcon(
            icon: Icons.text_fields_rounded,
            label: 'OCR',
            onTap: onOcr,
            color: isOcrRunning ? accent : textSecondary,
            isLoading: isOcrRunning,
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isLoading;

  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 26,
              width: 26,
              child: isLoading
                  ? Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      ),
                    )
                  : Icon(icon, size: 26, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PAGE SIZE CHIP ──────────────────────────────────────────────────────────

class _PageSizeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color surfaceCard;
  final Color surfaceBorder;
  final Color textPrimary;
  final Color textSecondary;

  const _PageSizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.surfaceCard,
    required this.surfaceBorder,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.18) : surfaceCard,
          border: Border.all(
            color: selected ? accent : surfaceBorder,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: selected ? accent : textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── OCR BOTTOM SHEET ────────────────────────────────────────────────────────

class _OcrBottomSheet extends StatelessWidget {
  final Color surfaceCard;
  final Color surfaceBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const _OcrBottomSheet({
    required this.surfaceCard,
    required this.surfaceBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocumentViewModel>();
    final text = vm.ocrText ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Extracted Text',
                      style: AppTextStyles.h4.copyWith(color: textPrimary),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: text.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: text),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard'),
                                ),
                              );
                            }
                          },
                    icon: Icon(
                      Icons.copy_rounded,
                      color: text.isEmpty ? textSecondary : accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: vm.isOcrRunning
                    ? Center(
                        child: CircularProgressIndicator(color: accent),
                      )
                    : text.isEmpty
                        ? Center(
                            child: Text(
                              'No text was detected on these pages.',
                              style: AppTextStyles.body
                                  .copyWith(color: textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : SingleChildScrollView(
                            controller: scrollController,
                            child: SelectableText(
                              text,
                              style: AppTextStyles.body
                                  .copyWith(color: textPrimary, height: 1.5),
                            ),
                          ),
              ),
              const SizedBox(height: AppSpacing.lg),
              BrainUpButton(
                label: 'Summarize with AI',
                onTap: text.isEmpty
                    ? null
                    : () {
                        Navigator.pop(context);
                        context.push('/ai/summarizer', extra: text);
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}
