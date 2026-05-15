import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class IncomingFileService {
  static StreamSubscription? _sub;

  static void initialize(BuildContext context) {
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty) _handleIncomingFiles(files, context);
    });
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) _handleIncomingFiles(files, context);
    });
  }

  static void _handleIncomingFiles(
      List<SharedMediaFile> files, BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IncomingFileSheet(files: files),
    );
  }

  static void dispose() => _sub?.cancel();
}

class _IncomingFileSheet extends StatelessWidget {
  final List<SharedMediaFile> files;
  const _IncomingFileSheet({required this.files});

  @override
  Widget build(BuildContext context) {
    final isPdf = files.any((f) => f.path.toLowerCase().endsWith('.pdf'));
    final isMultipleImages = files.length > 1;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Open with BrainUp', style: AppTextStyles.h4),
                    Text(
                      '${files.length} file${files.length > 1 ? 's' : ''} received',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isPdf) ...[
            _ActionTile(
              icon: Icons.picture_as_pdf_rounded,
              color: AppColors.error,
              title: 'View PDF',
              subtitle: 'Open in BrainUp PDF viewer',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/documents/pdf-viewer',
                  arguments: {
                    'path': files.first.path,
                    'title': files.first.path.split('/').last
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.accent,
              title: 'Analyze with AI',
              subtitle: 'Get summary, key topics, and study tips',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/documents/pdf-viewer',
                  arguments: {'path': files.first.path, 'autoAnalyze': true},
                );
              },
            ),
          ],
          if (isMultipleImages) ...[
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.picture_as_pdf_rounded,
              color: AppColors.accent,
              title: 'Convert to PDF',
              subtitle: '${files.length} images → one PDF',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/documents/image-to-pdf',
                  arguments: files.map((f) => f.path).toList(),
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}
