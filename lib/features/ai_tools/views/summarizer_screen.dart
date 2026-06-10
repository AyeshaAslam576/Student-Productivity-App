import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_markdown.dart';
import '../../../core/widgets/brainup_shimmer.dart';
import '../models/ai_session_model.dart';
import '../viewmodels/ai_viewmodel.dart';
import 'widgets/input_selector.dart';
import 'widgets/recent_sessions_sheet.dart';

class SummarizerScreen extends StatefulWidget {
  /// Pre-filled from document OCR / PDF viewer via route `extra`.
  final String? initialText;

  const SummarizerScreen({super.key, this.initialText});

  @override
  State<SummarizerScreen> createState() => _SummarizerScreenState();
}

class _SummarizerScreenState extends State<SummarizerScreen> {
  final _textCtrl = TextEditingController();
  final _inputKey = GlobalKey<InputSelectorState>();
  String _style = 'Detailed';
  final _styles = ['Brief', 'Detailed', 'Bullet Points'];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText?.trim();
    if (initial != null && initial.isNotEmpty) {
      _textCtrl.text = initial;
    }
    _textCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiViewModel>().loadRecentSessions();
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  /// Text sent to AI: file OCR when a file was uploaded, else the paste field.
  String _inputForAnalysis(AiViewModel vm) {
    if (vm.inputSource == InputSource.uploadedFile &&
        vm.currentInput.trim().isNotEmpty) {
      return vm.currentInput.trim();
    }
    return _textCtrl.text.trim();
  }

  bool _validate(AiViewModel vm) {
    final text = _inputForAnalysis(vm);
    String? message;
    if (text.isEmpty) {
      message = 'Please enter or upload text first';
    } else if (text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length < 10) {
      message = 'Text is too short. Add at least 10 words.';
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return false;
    }
    return true;
  }

  void _showRecentSessions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AiViewModel>(),
        child: Builder(
          builder: (sheetCtx) {
            final vm = sheetCtx.watch<AiViewModel>();
            final summarizerSessions = vm.recentSessions
                .where((s) => s.type == SessionType.summarizer)
                .toList();
            return RecentSessionsSheet(
              sessions: summarizerSessions,
              onSessionSelected: (session) {
                vm.loadSession(session);
                _textCtrl.text = session.originalInput;
                _style = session.metadata['style'] as String? ?? 'Detailed';
                setState(() {});
              },
              onSessionDeleted: vm.deleteSession,
              onSessionFavoriteToggle: vm.toggleSessionFavorite,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<AiViewModel>();
    final hasSessions = vm.recentSessions
        .any((s) => s.type == SessionType.summarizer);
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.surfaceBorder, width: 0.5)),
              ),
              child: Row(
                children: [
                  brainUpBackButton(
                    context,
                    fallback: brainupAiToolsFallback,
                    iconColor: colors.textPrimary,
                  ),
                  Icon(Icons.summarize_rounded, color: colors.accent, size: 22),
                  const SizedBox(width: 8),
                  Text('Summarizer', style: context.text.h3),
                  const Spacer(),
                  if (hasSessions)
                    IconButton(
                      onPressed: _showRecentSessions,
                      icon: Badge(
                        label: Text(
                          '${vm.recentSessions.where((s) => s.type == SessionType.summarizer).length}',
                          style:
                              const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          color: colors.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  if (vm.summaryResult.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _textCtrl.clear();
                        _inputKey.currentState?.clearFile();
                        vm.clearSummary();
                      },
                      icon: Icon(Icons.refresh_rounded, color: colors.textSecondary),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Style chips
                    Row(
                      children: _styles.map((s) {
                        final selected = _style == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _style = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected ? colors.accentSoft : colors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected ? colors.accent : colors.surfaceBorder,
                                  width: selected ? 1 : 0.5,
                                ),
                              ),
                              child: Text(s, style: context.text.labelSmall.copyWith(
                                color: selected ? colors.accent : colors.textSecondary,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                              )),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    InputSelector(
                      key: _inputKey,
                      hintText: 'Paste text to summarize...',
                      textCtrl: _textCtrl,
                      onFileSelected: (file) async {
                        if (file == null) return;
                        await vm.uploadFile(file);
                      },
                      onInputChanged: vm.setCurrentInput,
                    ),
                    const SizedBox(height: 14),
                    BrainUpButton(
                      label: 'Summarize',
                      isLoading: vm.summaryState == AiState.loading,
                      onTap: vm.summaryState == AiState.loading ||
                              _inputForAnalysis(vm).isEmpty
                          ? null
                          : () {
                              if (_validate(vm)) {
                                vm.summarize(_inputForAnalysis(vm),
                                    style: _style);
                              }
                            },
                      icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                    ),
                    // Output
                    if (vm.summaryState == AiState.loading) ...[
                      const SizedBox(height: 20),
                      const ShimmerList(count: 3),
                    ],
                    if (vm.summaryState == AiState.error) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(vm.error ?? 'An error occurred', style: context.text.bodySmall.copyWith(color: colors.error)),
                      ),
                    ],
                    if (vm.summaryState == AiState.done && vm.summaryResult.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      BrainUpCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.summarize_rounded, size: 18, color: colors.accent),
                                const SizedBox(width: 8),
                                Text('Summary', style: context.text.h5),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: vm.summaryResult));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Copied to clipboard')),
                                    );
                                  },
                                  icon: Icon(Icons.copy_rounded, size: 18, color: colors.textSecondary),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      Share.share(vm.summaryResult),
                                  icon: Icon(
                                    Icons.share_rounded,
                                    size: 18,
                                    color: colors.textSecondary,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            if (vm.summaryResult.isNotEmpty &&
                                _inputForAnalysis(vm).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    _CountChip(
                                      label: 'Original',
                                      count: _inputForAnalysis(vm)
                                          .split(RegExp(r'\s+'))
                                          .where((w) => w.isNotEmpty)
                                          .length,
                                      color: colors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: colors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    _CountChip(
                                      label: 'Summary',
                                      count: vm.summaryResult
                                          .trim()
                                          .split(RegExp(r'\s+'))
                                          .length,
                                      color: colors.success,
                                    ),
                                  ],
                                ),
                              ),
                            Divider(color: colors.surfaceBorder, height: 16),
                            BrainUpMarkdown(data: vm.summaryResult)
                                .animate()
                                .fadeIn(duration: 400.ms),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $count',
        style: context.text.caption.copyWith(color: color),
      ),
    );
  }
}
