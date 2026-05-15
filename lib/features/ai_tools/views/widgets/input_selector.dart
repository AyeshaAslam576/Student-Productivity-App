import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class InputSelector extends StatefulWidget {
  final String hintText;
  final TextEditingController textCtrl;
  final Future<void> Function(File?) onFileSelected;
  final ValueChanged<String> onInputChanged;

  const InputSelector({
    super.key,
    required this.hintText,
    required this.textCtrl,
    required this.onFileSelected,
    required this.onInputChanged,
  });

  @override
  State<InputSelector> createState() => InputSelectorState();
}

class InputSelectorState extends State<InputSelector> {
  bool _useFile = false;
  File? _selectedFile;
  bool _isProcessing = false;

  void clearFile() {
    setState(() {
      _selectedFile = null;
      _isProcessing = false;
      _useFile = false;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'docx', 'doc'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    setState(() {
      _selectedFile = file;
      _isProcessing = true;
    });

    try {
      await widget.onFileSelected(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedFile = null;
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process file: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              Expanded(
                child: _ModeTab(
                  icon: Icons.text_fields_rounded,
                  label: 'Paste Text',
                  isActive: !_useFile,
                  onTap: () => setState(() => _useFile = false),
                ),
              ),
              Expanded(
                child: _ModeTab(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload File',
                  isActive: _useFile,
                  onTap: () => setState(() => _useFile = true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!_useFile) ...[
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
            ),
            child: TextField(
              controller: widget.textCtrl,
              maxLines: 7,
              style: AppTextStyles.body,
              cursorColor: AppColors.accent,
              onChanged: widget.onInputChanged,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle:
                    AppTextStyles.body.copyWith(color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) {
                widget.textCtrl.text = data!.text!;
                widget.onInputChanged(data.text!);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Text pasted'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.paste_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Paste from clipboard',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_useFile) ...[
          GestureDetector(
            onTap: _isProcessing ? null : _pickFile,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: _selectedFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isProcessing)
                          const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.accent),
                          )
                        else ...[
                          const Icon(
                            Icons.cloud_upload_outlined,
                            size: 40,
                            color: AppColors.accent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to upload PDF, DOCX, or TXT',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Max 10MB',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 36,
                          color: AppColors.success,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFile!.uri.pathSegments.last,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text('Ready to analyze', style: AppTextStyles.caption),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isActive ? AppColors.accent : AppColors.textMuted,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
