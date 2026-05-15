import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/brainup_button.dart';
import '../../../../core/widgets/brainup_card.dart';
import '../../models/document_model.dart';
import '../../viewmodels/document_viewmodel.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onAnalyze;

  const DocumentCard({
    super.key,
    required this.document,
    this.onTap,
    this.onFavorite,
    this.onShare,
    this.onDelete,
    this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('doc-card-${document.id}'),
      direction: DismissDirection.horizontal,
      background: _SwipeBackground(
        color: AppColors.warning,
        icon: Icons.star_rounded,
        alignment: Alignment.centerLeft,
        label: document.isFavorite ? 'Unfavorite' : 'Favorite',
      ),
      secondaryBackground: const _SwipeBackground(
        color: AppColors.error,
        icon: Icons.delete_rounded,
        alignment: Alignment.centerRight,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onFavorite?.call();
          return false;
        }
        return await _confirmDelete(context);
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete?.call();
        }
      },
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: BrainUpCard(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Leading(document: document),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h5.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    _SubtitleRow(document: document),
                    const SizedBox(height: 4),
                    _TagRow(document: document),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showContextMenu(context),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Context menu (long-press / more button) ──────────────────────────────

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      document.title,
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
              icon: Icons.open_in_new_rounded,
              label: 'Open',
              onTap: () {
                Navigator.pop(sheetCtx);
                onTap?.call();
              },
            ),
            _MenuTile(
              icon: Icons.share_rounded,
              label: 'Share',
              iconColor: AppColors.accent,
              onTap: () {
                Navigator.pop(sheetCtx);
                final vm = context.read<DocumentViewModel>();
                onShare != null
                    ? onShare!()
                    : vm.shareDocument(document);
              },
            ),
            _MenuTile(
              icon: Icons.drive_file_rename_outline_rounded,
              label: 'Rename',
              onTap: () {
                Navigator.pop(sheetCtx);
                _showRenameDialog(context);
              },
            ),
            _MenuTile(
              icon: Icons.folder_open_rounded,
              label: 'Move to Folder',
              onTap: () {
                Navigator.pop(sheetCtx);
                _showMoveFolderSheet(
                  context,
                  document,
                  context.read<DocumentViewModel>(),
                );
              },
            ),
            _MenuTile(
              icon: Icons.psychology_rounded,
              label: 'Analyze with AI',
              iconColor: AppColors.info,
              onTap: () {
                Navigator.pop(sheetCtx);
                onAnalyze?.call();
              },
            ),
            _MenuTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              iconColor: AppColors.error,
              labelColor: AppColors.error,
              onTap: () async {
                Navigator.pop(sheetCtx);
                final ok = await _confirmDelete(context);
                if (ok) onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Rename dialog ────────────────────────────────────────────────────────

  Future<void> _showRenameDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: document.title);
    final vm = context.read<DocumentViewModel>();
    final newTitle = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text('Rename document', style: AppTextStyles.h4),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 1,
          style: AppTextStyles.body,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(dialogCtx, v.trim()),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: 'New name',
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null),
            child: Text(
              'Cancel',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
            child: Text(
              'Save',
              style: AppTextStyles.body.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty || newTitle == document.title) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await vm.repository.updateDocument(
        document.copyWith(title: newTitle),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not rename document. $e')),
      );
    }
  }

  // ─── Delete confirm dialog ────────────────────────────────────────────────

  Future<bool> _confirmDelete(BuildContext context) async {
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
          '"${document.title}" will be removed permanently. This cannot be undone.',
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

  // ─── Move to folder sheet (preserved from original) ──────────────────────

  void _showMoveFolderSheet(
    BuildContext context,
    DocumentModel doc,
    DocumentViewModel vm,
  ) {
    final folderCtrl = TextEditingController();
    final existingFolders = vm.allFolders.where((f) => f != 'All').toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(
                    Icons.folder_open_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text('Move to folder', style: AppTextStyles.h4),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Current folder: ${doc.folder}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                if (existingFolders.isNotEmpty) ...[
                  Text(
                    'Existing folders',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: existingFolders.map((f) {
                      final isCurrent = f == doc.folder;
                      return GestureDetector(
                        onTap: isCurrent
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await vm.moveDocumentToFolder(doc, f);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Moved to "$f"'),
                                    ),
                                  );
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.accent.withOpacity(0.15)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isCurrent
                                  ? AppColors.accent
                                  : AppColors.surfaceBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                size: 14,
                                color: isCurrent
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                f,
                                style: AppTextStyles.caption.copyWith(
                                  color: isCurrent
                                      ? AppColors.accent
                                      : AppColors.textPrimary,
                                  fontWeight: isCurrent
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'New folder',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: folderCtrl,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'e.g. Physics, Assignments…',
                        hintStyle: AppTextStyles.body
                            .copyWith(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.surfaceBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.surfaceBorder,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  BrainUpButton(
                    label: 'Move',
                    onTap: folderCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            final name = folderCtrl.text.trim();
                            Navigator.pop(ctx);
                            await vm.moveDocumentToFolder(doc, name);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Moved to "$name"'),
                                ),
                              );
                            }
                          },
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Leading thumbnail / icon ─────────────────────────────────────────────────

class _Leading extends StatelessWidget {
  final DocumentModel document;
  const _Leading({required this.document});

  IconData get _typeIcon {
    switch (document.type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf_rounded;
      case DocumentType.image:
        return Icons.image_rounded;
      case DocumentType.scanned:
        return Icons.document_scanner_rounded;
      case DocumentType.generated:
        return Icons.edit_document;
    }
  }

  Color get _typeColor {
    switch (document.type) {
      case DocumentType.pdf:
        return AppColors.error;
      case DocumentType.image:
        return AppColors.info;
      case DocumentType.scanned:
        return AppColors.accent;
      case DocumentType.generated:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumb = document.thumbnailPath;
    if (thumb != null && thumb.isNotEmpty) {
      final file = File(thumb);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            file,
            width: 46,
            height: 58,
            fit: BoxFit.cover,
            cacheWidth: 92,
            errorBuilder: (_, __, ___) => _iconFallback(),
          ),
        );
      }
    }
    return _iconFallback();
  }

  Widget _iconFallback() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _typeColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(_typeIcon, color: _typeColor),
    );
  }
}

// ─── Subtitle row (date · size · pages) ───────────────────────────────────────

class _SubtitleRow extends StatelessWidget {
  final DocumentModel document;
  const _SubtitleRow({required this.document});

  @override
  Widget build(BuildContext context) {
    final dot = Text(
      ' · ',
      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
    );
    return Row(
      children: [
        Flexible(
          child: Text(
            document.formattedDate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ),
        dot,
        Text(
          document.formattedSize,
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
        dot,
        Flexible(
          child: Text(
            document.pageCountLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

// ─── Tag row (subject + OCR + Local + favorite) ──────────────────────────────

class _TagRow extends StatelessWidget {
  final DocumentModel document;
  const _TagRow({required this.document});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (document.subjectTag != null) ...[
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.subjectColor(document.subjectTag!)
                    .withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                document.subjectTag!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        if (document.hasOcrText) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.success.withOpacity(0.4),
              ),
            ),
            child: Text(
              'OCR',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.success,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.phone_android_rounded,
                size: 9,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 3),
              Text(
                'Local',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (document.isFavorite)
          const Icon(
            Icons.star_rounded,
            size: 13,
            color: AppColors.warning,
          ),
      ],
    );
  }
}

// ─── Swipe backgrounds ───────────────────────────────────────────────────────

class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Alignment alignment;
  final String label;

  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.alignment,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isLeft) Icon(icon, color: Colors.white, size: 26),
          if (isLeft) const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.button.copyWith(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          if (!isLeft) const SizedBox(width: 8),
          if (!isLeft) Icon(icon, color: Colors.white, size: 26),
        ],
      ),
    );
  }
}

// ─── Menu tile ───────────────────────────────────────────────────────────────

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
      leading: Icon(
        icon,
        color: iconColor ?? AppColors.textSecondary,
      ),
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
