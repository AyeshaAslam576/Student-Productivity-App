import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../services/pdf_service.dart';
import '../viewmodels/document_viewmodel.dart';

class PdfGeneratorScreen extends StatefulWidget {
  const PdfGeneratorScreen({super.key});

  @override
  State<PdfGeneratorScreen> createState() => _PdfGeneratorScreenState();
}

class _PdfGeneratorScreenState extends State<PdfGeneratorScreen> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _content = TextEditingController();
  PdfTheme _theme = PdfTheme.academic;
  Color _accent = AppColors.accent;
  bool _saving = false;

  Future<void> _generate() async {
    setState(() => _saving = true);
    final pdf = await PdfService.generateFromRichText(
      title: _title.text.trim().isEmpty
          ? 'Generated Document'
          : _title.text.trim(),
      content: _content.text,
      author:
          _author.text.trim().isEmpty ? 'BrainUp User' : _author.text.trim(),
      theme: _theme,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    context.push(
      '/documents/pdf-viewer',
      extra: {'path': pdf.path, 'title': _title.text},
    );
  }

  @override
  Widget build(BuildContext context) {
    context.read<DocumentViewModel>();
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
          backgroundColor: AppColors.surface, title: const Text('Create PDF')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrainUpTextField(label: 'Title', controller: _title),
          const SizedBox(height: 10),
          BrainUpTextField(label: 'Author', controller: _author),
          const SizedBox(height: 10),
          BrainUpTextField(
            label: 'Content',
            controller: _content,
            maxLines: 12,
            hint: 'Write your lecture notes, assignment draft, or summary...',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: PdfTheme.values
                .map(
                  (t) => ChoiceChip(
                    label: Text(t.name),
                    selected: _theme == t,
                    onSelected: (_) => setState(() => _theme = t),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text('Accent Color', style: AppTextStyles.body),
          const SizedBox(height: 8),
          BlockPicker(
            pickerColor: _accent,
            onColorChanged: (c) => setState(() => _accent = c),
          ),
          const SizedBox(height: 14),
          BrainUpButton(
            label: 'Generate PDF',
            onTap: _saving ? null : _generate,
            isLoading: _saving,
          ),
        ],
      ),
    );
  }
}
