import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Copies [text] to the clipboard and opens the AI summarizer with it pre-filled.
Future<void> openSummarizerWithText(
  BuildContext context,
  String text, {
  bool showCopiedSnackBar = true,
}) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return;

  await Clipboard.setData(ClipboardData(text: trimmed));
  if (!context.mounted) return;

  if (showCopiedSnackBar) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  if (!context.mounted) return;
  context.push('/ai/summarizer', extra: trimmed);
}
