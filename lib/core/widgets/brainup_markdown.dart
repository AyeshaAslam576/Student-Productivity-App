import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../theme/app_palette.dart';

/// Renders AI-style markdown (headings, lists, bold, code) with app theming.
class BrainUpMarkdown extends StatelessWidget {
  final String data;
  final bool selectable;
  final Color? textColor;
  final Color? linkColor;
  final TextStyle? baseStyle;

  const BrainUpMarkdown({
    super.key,
    required this.data,
    this.selectable = true,
    this.textColor,
    this.linkColor,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final text = context.text;
    final foreground = textColor ?? colors.textPrimary;
    final accent = linkColor ?? colors.accent;
    final body = baseStyle ?? text.body.copyWith(color: foreground, height: 1.55);

    final sheet = MarkdownStyleSheet(
      p: body,
      h1: text.h4.copyWith(color: foreground, height: 1.3),
      h2: text.h5.copyWith(color: foreground, height: 1.3),
      h3: text.h5.copyWith(color: foreground, height: 1.3),
      h4: body.copyWith(fontWeight: FontWeight.w600),
      h5: body.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
      h6: body.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
      strong: body.copyWith(fontWeight: FontWeight.w700),
      em: body.copyWith(fontStyle: FontStyle.italic),
      del: body.copyWith(decoration: TextDecoration.lineThrough),
      blockquote: body.copyWith(color: colors.textSecondary),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: accent.withOpacity(0.6), width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      code: body.copyWith(
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: colors.surfaceElevated,
      ),
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.surfaceBorder, width: 0.5),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      listBullet: body,
      listIndent: 24,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.surfaceBorder, width: 0.5),
        ),
      ),
      a: body.copyWith(color: accent, decoration: TextDecoration.underline),
      tableHead: body.copyWith(fontWeight: FontWeight.w700),
      tableBody: body,
      tableBorder: TableBorder.all(color: colors.surfaceBorder, width: 0.5),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );

    return MarkdownBody(
      data: data,
      selectable: selectable,
      shrinkWrap: true,
      styleSheet: sheet,
    );
  }
}
