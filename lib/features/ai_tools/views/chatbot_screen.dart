import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../models/ai_session_model.dart';
import '../viewmodels/ai_viewmodel.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiViewModel>().loadRecentSessions();
    });
  }

  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    context.read<AiViewModel>().sendChatMessage(text);
    Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AiViewModel>();
    return Scaffold(
      backgroundColor: AppColors.surface,
      drawer: _ChatSessionsDrawer(vm: vm),
      body: SafeArea(
        child: Column(
          children: [
            // ─── AppBar ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                    bottom: BorderSide(
                        color: AppColors.surfaceBorder, width: 0.5)),
              ),
              child: Row(
                children: [
                  // Hamburger — opens the sessions drawer
                  Builder(
                    builder: (ctx) => IconButton(
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      icon: const Icon(Icons.menu_rounded,
                          color: AppColors.textPrimary),
                      tooltip: 'Chat History',
                    ),
                  ),
                  // Back
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                  ),
                  // Bot avatar
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy_rounded,
                        color: AppColors.info, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Chatbot', style: AppTextStyles.h4),
                      Row(
                        children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('Online · llama3.3-70b',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // New Chat
                  IconButton(
                    onPressed: () => vm.clearChat(),
                    icon: const Icon(Icons.add_rounded,
                        color: AppColors.accent, size: 24),
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),

            // ─── Messages ─────────────────────────────────────────────────
            Expanded(
              child: vm.chatMessages.isEmpty
                  ? SingleChildScrollView(
                      padding:
                          const EdgeInsets.all(AppSpacing.screenPadding),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.smart_toy_rounded,
                                  color: AppColors.info, size: 48),
                            ),
                            const SizedBox(height: 16),
                            Text('Hi! I\'m your AI study assistant',
                                style: AppTextStyles.h4,
                                textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text('Ask me anything academic!',
                                style: AppTextStyles.bodySmall,
                                textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                'Explain photosynthesis',
                                'Help me study calculus',
                                'Write a study plan',
                                'Summarize a topic',
                              ]
                                  .map((s) => GestureDetector(
                                        onTap: () {
                                          _ctrl.text = s;
                                          _send();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceElevated,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color:
                                                    AppColors.surfaceBorder,
                                                width: 0.5),
                                          ),
                                          child: Text(s,
                                              style:
                                                  AppTextStyles.labelSmall),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding:
                          const EdgeInsets.all(AppSpacing.screenPadding),
                      itemCount: vm.chatMessages.length +
                          (vm.chatState == AiState.loading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == vm.chatMessages.length) {
                          return const Align(
                            key: ValueKey('typing_indicator'),
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: _TypingIndicator(),
                            ),
                          );
                        }
                        final msg = vm.chatMessages[i];
                        return _ChatBubble(
                          key: ValueKey(
                              '${msg.isUser}_${msg.timestamp.millisecondsSinceEpoch}'),
                          message: msg.content,
                          isUser: msg.isUser,
                          time: msg.timestamp,
                        )
                            .animate(delay: 50.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.1);
                      },
                    ),
            ),

            // ─── Input row ────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border(
                    top: BorderSide(
                        color: AppColors.surfaceBorder, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: AppColors.surfaceBorder, width: 0.5),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        maxLines: null,
                        style: AppTextStyles.body,
                        cursorColor: AppColors.accent,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: AppTextStyles.body
                              .copyWith(color: AppColors.textMuted),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.accentGradient,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sessions Drawer ──────────────────────────────────────────────────────────

class _ChatSessionsDrawer extends StatelessWidget {
  final AiViewModel vm;
  const _ChatSessionsDrawer({required this.vm});

  @override
  Widget build(BuildContext context) {
    final sessions = vm.recentSessions
        .where((s) => s.type == SessionType.chatbot)
        .toList();

    return Drawer(
      backgroundColor: AppColors.surfaceCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  Text('Chat History', style: AppTextStyles.h4),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      vm.clearChat();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add_rounded,
                        color: AppColors.accent, size: 22),
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceBorder, height: 1),
            const SizedBox(height: 8),

            // ── Sessions list ───────────────────────────────────────────
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              color: AppColors.textMuted, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'No previous chats',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: sessions.length,
                      itemBuilder: (_, i) {
                        final s = sessions[i];
                        return _SessionTile(
                          key: ValueKey(s.id),
                          session: s,
                          vm: vm,
                          onTap: () {
                            // Update state + notifyListeners while drawer is
                            // still alive, THEN close it — no rebuild during
                            // the close animation.
                            vm.switchToChatSession(s);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Session Tile ─────────────────────────────────────────────────────────────

class _SessionTile extends StatefulWidget {
  final AiSession session;
  final AiViewModel vm;
  final VoidCallback onTap;
  const _SessionTile(
      {super.key, required this.session, required this.vm, required this.onTap});

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF1A3A5C),
        child: Icon(Icons.chat_bubble_outline_rounded,
            color: AppColors.accent, size: 16),
      ),
      title: Text(
        widget.session.preview,
        style:
            AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        widget.session.formattedDate,
        style: AppTextStyles.caption
            .copyWith(color: AppColors.textMuted, fontSize: 10),
      ),
      trailing: PopupMenuButton<_SessionAction>(
        color: AppColors.surfaceElevated,
        icon: const Icon(Icons.more_vert_rounded,
            color: AppColors.textMuted, size: 18),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: _onAction,
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _SessionAction.rename,
            child: _MenuRow(
              icon: Icons.drive_file_rename_outline_rounded,
              label: 'Rename',
              color: AppColors.accent,
            ),
          ),
          PopupMenuItem(
            value: _SessionAction.export,
            child: _MenuRow(
              icon: Icons.picture_as_pdf_rounded,
              label: 'Export as PDF',
              color: AppColors.success,
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: _SessionAction.delete,
            child: _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppColors.error,
            ),
          ),
        ],
      ),
      onTap: widget.onTap,
    );
  }

  Future<void> _onAction(_SessionAction action) async {
    switch (action) {
      case _SessionAction.rename:
        await _showRenameDialog();
      case _SessionAction.export:
        await _exportAsPdf();
      case _SessionAction.delete:
        await _confirmDelete();
    }
  }

  Future<void> _showRenameDialog() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialText: widget.session.preview),
    );
    if (!mounted) return;
    if (newName != null && newName.trim().isNotEmpty) {
      await widget.vm.renameSession(widget.session.id, newName.trim());
    }
  }

  Future<void> _exportAsPdf() async {
    final messages = widget.session.chatHistory;
    if (messages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to export')),
      );
      return;
    }

    // Load Unicode-capable fonts — Helvetica (the pdf default) has no Unicode
    // support and cannot render any non-ASCII character in AI responses, which
    // corrupts layout measurements and causes TooManyPagesException.
    final regularFont = await PdfGoogleFonts.nunitoSansRegular();
    final boldFont = await PdfGoogleFonts.nunitoSansBold();
    if (!mounted) return;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 200,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          pw.Text(
            widget.session.preview,
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Exported from BrainUp AI Chat  |  ${widget.session.formattedDate}',
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Divider(height: 24, color: PdfColors.grey300),
          ...messages.map((m) {
            final isUser = m.isUser;
            final time =
                '${m.timestamp.hour}:${m.timestamp.minute.toString().padLeft(2, '0')}';
            // Plain column layout — avoids atomic rounded containers that
            // cannot split across pages for long AI responses.
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 12,
                        color: isUser ? PdfColors.blue400 : PdfColors.grey400,
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        isUser ? 'You' : 'AI Assistant',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: isUser
                              ? PdfColors.blue700
                              : PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        time,
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey500),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 10),
                    child: pw.Text(
                      m.content,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    final Uint8List pdfBytes = await doc.save();
    if (!mounted) return;

    final fileName =
        '${widget.session.preview.replaceAll(RegExp(r'[^\w\s]'), '').trim().replaceAll(' ', '_')}_chat.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Chat?', style: AppTextStyles.h4),
        content: Text(
          '"${widget.session.preview}" will be permanently deleted.',
          style: AppTextStyles.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await widget.vm.deleteSession(widget.session.id);
    }
  }
}

// ─── Menu action enum ─────────────────────────────────────────────────────────

enum _SessionAction { rename, export, delete }

// ─── Rename dialog ────────────────────────────────────────────────────────────

class _RenameDialog extends StatefulWidget {
  final String initialText;
  const _RenameDialog({required this.initialText});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Rename Chat', style: AppTextStyles.h4),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: AppTextStyles.body,
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: 'Enter a name...',
          hintStyle:
              AppTextStyles.body.copyWith(color: AppColors.textMuted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: AppColors.surfaceBorder, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Save',
              style: AppTextStyles.body.copyWith(
                  color: AppColors.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Reusable menu row ────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuRow(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Text(label,
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}

// ─── Chat Bubble ──────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime time;

  const _ChatBubble(
      {super.key, required this.message, required this.isUser, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 16, color: AppColors.info),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isUser ? AppColors.accentGradient : null,
                    color: isUser ? null : AppColors.surfaceCard,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: AppColors.surfaceBorder, width: 0.5),
                  ),
                  child: SelectableText(
                    message,
                    style: AppTextStyles.body.copyWith(
                      color:
                          isUser ? Colors.white : AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppDateUtils.formatTime(time),
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
                if (!isUser) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: AppColors.accentGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600))
        ..repeat(reverse: true);
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) c.forward();
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controllers[i],
            builder: (_, __) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(
                    0.4 + _controllers[i].value * 0.6),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}
