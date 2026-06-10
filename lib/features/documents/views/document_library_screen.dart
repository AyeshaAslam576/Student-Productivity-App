import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/back_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_app_bar.dart';
import '../../../core/widgets/brainup_empty_state.dart';
import '../models/document_model.dart';
import '../viewmodels/document_viewmodel.dart';
import 'widgets/document_card.dart';

class DocumentLibraryScreen extends StatefulWidget {
  final String? initialSubject;
  const DocumentLibraryScreen({super.key, this.initialSubject});

  @override
  State<DocumentLibraryScreen> createState() => _DocumentLibraryScreenState();
}

class _DocumentLibraryScreenState extends State<DocumentLibraryScreen> {
  bool _grid = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialSubject != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context
            .read<DocumentViewModel>()
            .setSubjectFilter(widget.initialSubject);
      });
    }
  }

  Stream<List<DocumentModel>> _resolveStream(DocumentViewModel vm) {
    if (widget.initialSubject != null) {
      return vm.watchBySubject(widget.initialSubject!);
    }
    final folder = vm.selectedFolder;
    if (folder != 'All') return vm.watchByFolder(folder);
    return vm.watchAllDocuments();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocumentViewModel>();
    final hasSubject = widget.initialSubject != null;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: BrainUpAppBar(
        title: widget.initialSubject ?? 'All Documents',
        leading: brainUpBackButton(context,
            fallback: '/documents', iconColor: colors.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Sort',
            onPressed: () => _showSortSheet(context, vm),
            icon: Icon(
              Icons.sort_rounded,
              color: colors.textSecondary,
            ),
          ),
          IconButton(
            tooltip: _grid ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _grid = !_grid),
            icon: Icon(
              _grid ? Icons.list_rounded : Icons.grid_view_rounded,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: () => _showAddSheet(context, vm),
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<List<DocumentModel>>(
        stream: _resolveStream(vm),
        builder: (context, snapshot) {
          final docs = snapshot.data ?? const <DocumentModel>[];
          final isWaiting =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

          return Column(
            children: [
              if (hasSubject)
                _SubjectHeader(
                  subject: widget.initialSubject!,
                  docCount: docs.length,
                ),
              Expanded(
                child: _DocumentContent(
                  docs: docs,
                  grid: _grid,
                  isWaiting: isWaiting,
                  vm: vm,
                  onScan: () => vm.startEdgeScan(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Sheets ────────────────────────────────────────────────────────────────

  void _showSortSheet(BuildContext context, DocumentViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = ctx.colors;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 16),
              Text('Sort by', style: ctx.text.h4),
              const SizedBox(height: 12),
              ...SortOption.values.map((option) {
                final selected = vm.sortBy == option;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(
                    _sortIcon(option),
                    color:
                        selected ? colors.accent : colors.textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    _sortLabel(option),
                    style: ctx.text.body.copyWith(
                      color:
                          selected ? colors.accent : colors.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  trailing: selected
                      ? Icon(
                          Icons.check_rounded,
                          color: colors.accent,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    vm.setSortOption(option);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showAddSheet(BuildContext context, DocumentViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = ctx.colors;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 16),
              Text('Add document', style: ctx.text.h4),
              const SizedBox(height: 12),
              _AddTile(
                icon: Icons.document_scanner_rounded,
                color: colors.accent,
                title: 'Scan with camera',
                subtitle: 'Capture pages with edge detection',
                onTap: () {
                  Navigator.pop(ctx);
                  vm.startEdgeScan(context);
                },
              ),
              const SizedBox(height: 8),
              _AddTile(
                icon: Icons.upload_file_rounded,
                color: colors.info,
                title: 'Import PDF',
                subtitle: 'Pick a PDF from your device',
                onTap: () {
                  Navigator.pop(ctx);
                  vm.importPdf();
                },
              ),
              const SizedBox(height: 8),
              _AddTile(
                icon: Icons.photo_library_rounded,
                color: colors.success,
                title: 'Import from gallery',
                subtitle: 'Use images already on your phone',
                onTap: () {
                  Navigator.pop(ctx);
                  vm.importFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _sortIcon(SortOption o) {
    switch (o) {
      case SortOption.lastOpened:
        return Icons.history_rounded;
      case SortOption.createdAt:
        return Icons.event_rounded;
      case SortOption.name:
        return Icons.sort_by_alpha_rounded;
      case SortOption.size:
        return Icons.data_usage_rounded;
    }
  }

  String _sortLabel(SortOption o) {
    switch (o) {
      case SortOption.lastOpened:
        return 'Last opened';
      case SortOption.createdAt:
        return 'Date created';
      case SortOption.name:
        return 'Name';
      case SortOption.size:
        return 'Size';
    }
  }
}

// ─── Subject header ──────────────────────────────────────────────────────────

class _SubjectHeader extends StatelessWidget {
  final String subject;
  final int docCount;

  const _SubjectHeader({required this.subject, required this.docCount});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.subjectColor(subject);
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.h3.copyWith(color: Colors.white),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: Text(
              docCount == 1 ? '1 doc' : '$docCount docs',
              style: context.text.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Document content (grid / list / empty) ─────────────────────────────────

class _DocumentContent extends StatelessWidget {
  final List<DocumentModel> docs;
  final bool grid;
  final bool isWaiting;
  final DocumentViewModel vm;
  final VoidCallback onScan;

  const _DocumentContent({
    required this.docs,
    required this.grid,
    required this.isWaiting,
    required this.vm,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    if (isWaiting) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.accent),
      );
    }
    if (docs.isEmpty) {
      return BrainUpEmptyState(
        title: 'No documents here',
        subtitle: 'Tap + to scan or import your first document.',
        actionLabel: 'Scan now',
        onAction: onScan,
      );
    }

    final bottomPad = MediaQuery.paddingOf(context).bottom + 96;

    if (grid) {
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: docs.length,
        itemBuilder: (_, i) => _DocumentGridCard(
          doc: docs[i],
          onTap: () => vm.openDocument(docs[i], context),
          onFavorite: () => vm.toggleFavorite(docs[i].id),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
      physics: const BouncingScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DocumentCard(
          document: docs[i],
          onTap: () => vm.openDocument(docs[i], context),
          onFavorite: () => vm.toggleFavorite(docs[i].id),
          onShare: () => vm.shareDocument(docs[i]),
          onDelete: () => vm.deleteDocument(docs[i].id),
          onAnalyze: () => vm.analyzeDocument(docs[i]),
        ),
      ),
    );
  }
}

// ─── Document grid card (mirrors DocumentsScreen) ───────────────────────────

class _DocumentGridCard extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _DocumentGridCard({
    required this.doc,
    required this.onTap,
    required this.onFavorite,
  });

  IconData get _typeIcon {
    switch (doc.type) {
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

  Color _typeColor(BuildContext context) {
    final colors = context.colors;
    switch (doc.type) {
      case DocumentType.pdf:
        return colors.error;
      case DocumentType.image:
        return colors.info;
      case DocumentType.scanned:
        return colors.accent;
      case DocumentType.generated:
        return colors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subjectColor =
        doc.subjectTag != null ? AppColors.subjectColor(doc.subjectTag!) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: colors.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildPreview(context)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          doc.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 16,
                          color: doc.isFavorite
                              ? colors.warning
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.h5.copyWith(
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${doc.pageCountLabel} · ${doc.formattedSize}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption.copyWith(
                      color: colors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  if (doc.subjectTag != null && subjectColor != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: subjectColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: subjectColor.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          doc.subjectTag!,
                          style: context.text.caption.copyWith(
                            color: subjectColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final thumb = doc.thumbnailPath;
    if (thumb != null && thumb.isNotEmpty) {
      final file = File(thumb);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(context),
        );
      }
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final colors = context.colors;
    final typeColor = _typeColor(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withOpacity(0.18),
            colors.surfaceElevated,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(_typeIcon, size: 64, color: typeColor.withOpacity(0.65)),
    );
  }
}

// ─── Add-document tile ───────────────────────────────────────────────────────

class _AddTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AddTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.text.caption
                          .copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sheet handle ────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: context.colors.surfaceBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
