import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_shimmer.dart';
import '../models/ai_session_model.dart';
import '../viewmodels/ai_viewmodel.dart';
import 'widgets/input_selector.dart';
import 'widgets/recent_sessions_sheet.dart';

class SummarizerScreen extends StatefulWidget {
  const SummarizerScreen({super.key});

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

  bool _validate() {
    final text = _textCtrl.text.trim();
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
    final vm = context.read<AiViewModel>();
    final summarizerSessions =
        vm.recentSessions.where((s) => s.type == SessionType.summarizer).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RecentSessionsSheet(
        sessions: summarizerSessions,
        onSessionSelected: (session) {
          vm.loadSession(session);
          _textCtrl.text = session.originalInput;
          _style = session.metadata['style'] as String? ?? 'Detailed';
          setState(() {});
        },
        onSessionDeleted: vm.deleteSession,
        onSessionFavoriteToggle: vm.toggleSessionFavorite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AiViewModel>();
    final hasSessions = vm.recentSessions
        .any((s) => s.type == SessionType.summarizer);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  ),
                  const Icon(Icons.summarize_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 8),
                  Text('Summarizer', style: AppTextStyles.h3),
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
                        child: const Icon(
                          Icons.history_rounded,
                          color: AppColors.textSecondary,
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
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
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
                                color: selected ? AppColors.accentSoft : AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected ? AppColors.accent : AppColors.surfaceBorder,
                                  width: selected ? 1 : 0.5,
                                ),
                              ),
                              child: Text(s, style: AppTextStyles.labelSmall.copyWith(
                                color: selected ? AppColors.accent : AppColors.textSecondary,
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
                        if (mounted && vm.currentInput.isNotEmpty) {
                          _textCtrl.text = vm.currentInput;
                        }
                      },
                      onInputChanged: vm.setCurrentInput,
                    ),
                    const SizedBox(height: 14),
                    BrainUpButton(
                      label: 'Summarize',
                      isLoading: vm.summaryState == AiState.loading,
                      onTap: vm.summaryState == AiState.loading ||
                              _textCtrl.text.trim().isEmpty
                          ? null
                          : () {
                              if (_validate()) {
                                vm.summarize(_textCtrl.text.trim(),
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
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(vm.error ?? 'An error occurred', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
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
                                const Icon(Icons.summarize_rounded, size: 18, color: AppColors.accent),
                                const SizedBox(width: 8),
                                Text('Summary', style: AppTextStyles.h5),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: vm.summaryResult));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Copied to clipboard')),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      Share.share(vm.summaryResult),
                                  icon: const Icon(
                                    Icons.share_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            if (vm.summaryResult.isNotEmpty &&
                                _textCtrl.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    _CountChip(
                                      label: 'Original',
                                      count: _textCtrl.text
                                          .trim()
                                          .split(RegExp(r'\s+'))
                                          .length,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    _CountChip(
                                      label: 'Summary',
                                      count: vm.summaryResult
                                          .trim()
                                          .split(RegExp(r'\s+'))
                                          .length,
                                      color: AppColors.success,
                                    ),
                                  ],
                                ),
                              ),
                            const Divider(color: AppColors.surfaceBorder, height: 16),
                            Text(
                              vm.summaryResult,
                              style: AppTextStyles.body.copyWith(height: 1.6),
                            ).animate().fadeIn(duration: 400.ms),
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
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}
