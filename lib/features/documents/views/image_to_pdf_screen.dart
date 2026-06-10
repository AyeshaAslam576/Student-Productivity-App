import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/back_navigation.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_empty_state.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';
import '../viewmodels/document_viewmodel.dart';

class ImageToPdfScreen extends StatefulWidget {
  final List<String>? initialPaths;
  const ImageToPdfScreen({super.key, this.initialPaths});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  List<File> _images = [];
  PdfPageSize _pageSize = PdfPageSize.a4;
  bool _isConverting = false;
  double _conversionProgress = 0;

  @override
  void initState() {
    super.initState();
    _images = (widget.initialPaths ?? []).map((p) => File(p)).toList();
  }

  Future<void> _addImages() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (picked == null) return;
    setState(() {
      _images.addAll(
          picked.files.where((e) => e.path != null).map((e) => File(e.path!)));
    });
  }

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    setState(() {
      _isConverting = true;
      _conversionProgress = 0;
    });
    for (int i = 0; i < _images.length; i++) {
      _conversionProgress = (i + 1) / _images.length;
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    final file = await PdfService.imagesToPdf(
      _images,
      title: 'Images_${DateTime.now().millisecondsSinceEpoch}',
      pageSize: _pageSize,
    );
    if (!mounted) return;
    setState(() => _isConverting = false);
    context.push(
      '/documents/pdf-viewer',
      extra: {'path': file.path, 'title': 'Image PDF'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<DocumentViewModel>();
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        automaticallyImplyLeading: false,
        leading: brainUpBackButton(context,
            fallback: '/documents', iconColor: colors.textPrimary),
        title: const Text('Image to PDF'),
        actions: [
          IconButton(
              onPressed: _addImages,
              icon: const Icon(Icons.add_photo_alternate_rounded))
        ],
      ),
      body: _images.isEmpty
          ? BrainUpEmptyState(
              title: 'Add images to convert',
              subtitle: 'Select from gallery or open with BrainUp',
              actionLabel: 'Add Images',
              onAction: _addImages,
            )
          : Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _images.length,
                    onReorder: (o, n) {
                      setState(() {
                        if (n > o) n--;
                        final image = _images.removeAt(o);
                        _images.insert(n, image);
                      });
                    },
                    itemBuilder: (_, i) => Container(
                      key: ValueKey(_images[i].path),
                      margin: const EdgeInsets.only(bottom: 10),
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.surfaceBorder),
                        image: DecorationImage(
                            image: FileImage(_images[i]), fit: BoxFit.cover),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 8,
                            top: 8,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Text('${i + 1}',
                                  style: context.text.caption),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: InkWell(
                              onTap: () => setState(() => _images.removeAt(i)),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close_rounded, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceCard,
                    border:
                        Border(top: BorderSide(color: colors.surfaceBorder)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: PdfPageSize.values
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(s.name.toUpperCase()),
                                  selected: _pageSize == s,
                                  onSelected: (_) =>
                                      setState(() => _pageSize = s),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('${_images.length} images selected',
                              style: context.text.bodySmall),
                          const Spacer(),
                          if (_isConverting)
                            Text(
                                '${(_conversionProgress * 100).toStringAsFixed(0)}%',
                                style: context.text.caption),
                        ],
                      ),
                      const SizedBox(height: 10),
                      BrainUpButton(
                        label: 'Convert to PDF',
                        isLoading: _isConverting,
                        onTap: _isConverting ? null : _convert,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: vm.importFromGallery,
        child: const Icon(Icons.photo_library_outlined),
      ),
    );
  }
}
