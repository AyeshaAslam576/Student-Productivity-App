import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../models/document_model.dart';
import '../viewmodels/document_viewmodel.dart';
import 'widgets/document_card.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedFilter = 'All';
  bool _isGrid = true;
  final Set<String> _pendingFolders = {};

  static const _filters = ['All', 'PDFs', 'Images', 'Scanned', 'Favorites'];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DocumentModel> _categoryFiltered(DocumentViewModel vm) {
    final items = vm.filteredDocuments;
    switch (_selectedFilter) {
      case 'PDFs':
        return items.where((d) => d.type == DocumentType.pdf).toList();
      case 'Images':
        return items.where((d) => d.type == DocumentType.image).toList();
      case 'Scanned':
        return items
            .where((d) => d.source == DocumentSource.scanned)
            .toList();
      case 'Favorites':
        return items.where((d) => d.isFavorite).toList();
      default:
        return items;
    }
  }

  List<String> _folderChips(DocumentViewModel vm) {
    final base = List<String>.from(vm.allFolders);
    for (final f in _pendingFolders) {
      if (!base.contains(f)) base.add(f);
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocumentViewModel>();
    final filtered = _categoryFiltered(vm);

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: vm.isScanProcessing
          ? null
          : _ScanFAB(
              onPressed: () => vm.startEdgeScan(context),
            ),
      body: Stack(
        children: [
          CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(vm),
          SliverToBoxAdapter(child: _QuickActionRow(vm: vm)),
          SliverToBoxAdapter(
            child: _FolderSection(
              folders: _folderChips(vm),
              selectedFolder: vm.selectedFolder,
              onSelect: vm.setFolder,
              onCreate: () => _showCreateFolderSheet(context, vm),
            ),
          ),
          SliverToBoxAdapter(
            child: _SearchAndFilter(
              controller: _searchCtrl,
              isGrid: _isGrid,
              onSearchChanged: vm.setSearchQuery,
              onToggleView: () => setState(() => _isGrid = !_isGrid),
              onOpenFilter: () => _showFilterSheet(context, vm),
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterChipsRow(
              filters: _filters,
              selected: _selectedFilter,
              onSelect: (f) => setState(() => _selectedFilter = f),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context, vm,
                  hasAnyDocs: vm.allDocuments.isNotEmpty),
            )
          else if (_isGrid)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                MediaQuery.paddingOf(context).bottom + 100,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _DocumentGridCard(
                    doc: filtered[i],
                    onTap: () => vm.openDocument(filtered[i], context),
                    onFavorite: () => vm.toggleFavorite(filtered[i].id),
                  ),
                  childCount: filtered.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                MediaQuery.paddingOf(context).bottom + 100,
              ),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DocumentCard(
                    document: filtered[i],
                    onTap: () => vm.openDocument(filtered[i], context),
                    onFavorite: () => vm.toggleFavorite(filtered[i].id),
                    onShare: () => vm.shareDocument(filtered[i]),
                    onDelete: () => vm.deleteDocument(filtered[i].id),
                    onAnalyze: () => vm.analyzeDocument(filtered[i]),
                  ),
                ),
              ),
            ),
        ],
          ),
          if (vm.isScanProcessing && vm.scanProgress > 0)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(
                    'Preparing your scan…',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (vm.scanProgress > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${(vm.scanProgress * 100).round()}%',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── SLIVER APP BAR ────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(DocumentViewModel vm) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 140,
      elevation: 0,
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      title: Text(
        'Documents',
        style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
      ),
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.file_copy_outlined,
                  value: '${vm.totalDocuments}',
                  label: 'Files',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  icon: Icons.document_scanner_rounded,
                  value: '${vm.totalScanned}',
                  label: 'Scanned',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  icon: Icons.storage_rounded,
                  value: vm.totalStorageMB.toStringAsFixed(1),
                  label: 'MB',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── EMPTY STATE ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(
    BuildContext context,
    DocumentViewModel vm, {
    required bool hasAnyDocs,
  }) {
    if (hasAnyDocs) {
      final (IconData icon, String title, String sub, String? action,
          VoidCallback? onAction) = switch (_selectedFilter) {
        'PDFs' => (
            Icons.picture_as_pdf_rounded,
            'No PDFs yet',
            'Import a PDF to see it here',
            'Import PDF',
            vm.importPdf,
          ),
        'Images' => (
            Icons.image_outlined,
            'No images yet',
            'Import image files to see them here',
            'Import',
            vm.importPdf,
          ),
        'Scanned' => (
            Icons.document_scanner_rounded,
            'No scanned documents',
            'Tap Scan to capture pages with your camera',
            'Scan Now',
            () => vm.startEdgeScan(context),
          ),
        'Favorites' => (
            Icons.star_outline_rounded,
            'No favorites yet',
            'Star any document to pin it here',
            null,
            null,
          ),
        _ => (
            Icons.search_off_rounded,
            'No results found',
            'Try a different search term',
            null,
            null,
          ),
      };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Icon(icon, size: 30, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppTextStyles.h4),
              const SizedBox(height: 8),
              Text(
                sub,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              if (action != null && onAction != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  child: BrainUpButton(label: action, onTap: onAction),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 36,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text('Your documents live here', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            Text(
              'Scan notes, import PDFs or create\ndocuments — stored safely on device',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: BrainUpButton(
                label: 'Scan Now',
                onTap: () => vm.startEdgeScan(context),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 220,
              child: BrainUpButton.secondary(
                label: 'Import PDF',
                onTap: vm.importPdf,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SHEETS ───────────────────────────────────────────────────────────────

  void _showFilterSheet(BuildContext context, DocumentViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 16),
            Text('Sort & Filter', style: AppTextStyles.h4),
            const SizedBox(height: 16),
            Text(
              'Sort by',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SortOption.values.map((option) {
                return ChoiceChip(
                  label: Text(option.name),
                  selected: vm.sortBy == option,
                  selectedColor: AppColors.accent.withOpacity(0.2),
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: AppTextStyles.bodySmall.copyWith(
                    color: vm.sortBy == option
                        ? AppColors.accent
                        : AppColors.textPrimary,
                    fontWeight: vm.sortBy == option
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: vm.sortBy == option
                        ? AppColors.accent
                        : AppColors.surfaceBorder,
                  ),
                  onSelected: (_) {
                    vm.setSortOption(option);
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    vm.clearFilters();
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Clear All',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                BrainUpButton.small(
                  label: 'Apply',
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderSheet(BuildContext context, DocumentViewModel vm) {
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 16),
              Text('New Folder', style: AppTextStyles.h4),
              const SizedBox(height: 16),
              BrainUpTextField(
                label: 'Folder name',
                hint: 'e.g. Maths Notes',
                controller: ctrl,
                autofocus: true,
                prefixIcon: const Icon(
                  Icons.folder_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              BrainUpButton(
                label: 'Create',
                onTap: () {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) {
                    Navigator.pop(ctx);
                    return;
                  }
                  setState(() => _pendingFolders.add(name));
                  vm.setFolder(name);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SCAN FAB ───────────────────────────────────────────────────────────────

class _ScanFAB extends StatelessWidget {
  final VoidCallback onPressed;
  const _ScanFAB({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.document_scanner_rounded),
      label: Text(
        '',
        style: AppTextStyles.button.copyWith(color: Colors.white),
      ),
    );
  }
}

// ─── STAT CHIP ──────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.85),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$value ',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: label,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QUICK ACTION ROW ───────────────────────────────────────────────────────

class _QuickActionRow extends StatelessWidget {
  final DocumentViewModel vm;
  const _QuickActionRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    final tiles = <_QuickAction>[
      _QuickAction(
        icon: Icons.document_scanner_rounded,
        label: 'Scan',
        color: AppColors.accent,
        onTap: () => vm.startEdgeScan(context),
      ),
      _QuickAction(
        icon: Icons.upload_file_rounded,
        label: 'Import',
        color: AppColors.info,
        onTap: vm.importPdf,
      ),
      _QuickAction(
        icon: Icons.photo_library_rounded,
        label: 'Gallery',
        color: AppColors.success,
        onTap: vm.importFromGallery,
      ),
      _QuickAction(
        icon: Icons.qr_code_scanner_rounded,
        label: 'QR',
        color: AppColors.warning,
        onTap: () => context.push('/documents/qr'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            Expanded(child: _QuickActionTile(action: tiles[i])),
            if (i != tiles.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        height: 86,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, color: action.color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FOLDER SECTION ─────────────────────────────────────────────────────────

class _FolderSection extends StatelessWidget {
  final List<String> folders;
  final String selectedFolder;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;

  const _FolderSection({
    required this.folders,
    required this.selectedFolder,
    required this.onSelect,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: folders.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == folders.length) {
            return _CreateFolderChip(onTap: onCreate);
          }
          final folder = folders[i];
          final isSelected = folder == selectedFolder;
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_rounded,
                  size: 14,
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(folder),
              ],
            ),
            selected: isSelected,
            selectedColor: AppColors.accent.withOpacity(0.18),
            backgroundColor: AppColors.surfaceCard,
            side: BorderSide(
              color: isSelected ? AppColors.accent : AppColors.surfaceBorder,
            ),
            labelStyle: AppTextStyles.bodySmall.copyWith(
              color:
                  isSelected ? AppColors.accent : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            showCheckmark: false,
            onSelected: (_) => onSelect(folder),
          );
        },
      ),
    );
  }
}

class _CreateFolderChip extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateFolderChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: const Icon(
        Icons.add_rounded,
        size: 16,
        color: AppColors.accent,
      ),
      label: Text(
        'New',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppColors.surfaceCard,
      side: const BorderSide(color: AppColors.accent),
    );
  }
}

// ─── SEARCH & FILTER ────────────────────────────────────────────────────────

class _SearchAndFilter extends StatelessWidget {
  final TextEditingController controller;
  final bool isGrid;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleView;
  final VoidCallback onOpenFilter;

  const _SearchAndFilter({
    required this.controller,
    required this.isGrid,
    required this.onSearchChanged,
    required this.onToggleView,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: BrainUpTextField(
              label: 'Search',
              hint: 'Search documents…',
              controller: controller,
              onChanged: onSearchChanged,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () {
                        controller.clear();
                        onSearchChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(width: 8),
          _SquareIconButton(
            icon: Icons.tune_rounded,
            onTap: onOpenFilter,
            tooltip: 'Sort & filter',
          ),
          const SizedBox(width: 6),
          _SquareIconButton(
            icon: isGrid ? Icons.list_rounded : Icons.grid_view_rounded,
            onTap: onToggleView,
            tooltip: isGrid ? 'List view' : 'Grid view',
          ),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _SquareIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 20),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

// ─── FILTER CHIPS ROW ───────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterChipsRow({
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  IconData _iconFor(String f) {
    switch (f) {
      case 'PDFs':
        return Icons.picture_as_pdf_rounded;
      case 'Images':
        return Icons.image_rounded;
      case 'Scanned':
        return Icons.document_scanner_rounded;
      case 'Favorites':
        return Icons.star_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSelected = f == selected;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.accentGradient : null,
                color: isSelected ? null : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(999),
                border: isSelected
                    ? null
                    : Border.all(color: AppColors.surfaceBorder),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconFor(f),
                    size: 14,
                    color:
                        isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f,
                    style: AppTextStyles.caption.copyWith(
                      color:
                          isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── DOCUMENT GRID CARD ─────────────────────────────────────────────────────

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

  Color get _typeColor {
    switch (doc.type) {
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
    final subjectColor =
        doc.subjectTag != null ? AppColors.subjectColor(doc.subjectTag!) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildPreview()),
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
                              ? AppColors.warning
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
                    style: AppTextStyles.h5.copyWith(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${doc.pageCountLabel} · ${doc.formattedSize}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
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
                          style: AppTextStyles.caption.copyWith(
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

  Widget _buildPreview() {
    final thumb = doc.thumbnailPath;
    if (thumb != null && thumb.isNotEmpty) {
      final file = File(thumb);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      }
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _typeColor.withOpacity(0.18),
            AppColors.surfaceElevated,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(_typeIcon, size: 64, color: _typeColor.withOpacity(0.65)),
    );
  }
}

// ─── COMMON ─────────────────────────────────────────────────────────────────

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
