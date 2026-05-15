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
import '../../documents/services/pdf_service.dart';
import '../models/ai_session_model.dart';
import '../viewmodels/ai_viewmodel.dart';
import 'widgets/input_selector.dart';
import 'widgets/recent_sessions_sheet.dart';

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiViewModel>().loadRecentSessions();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final text = _ctrl.text.trim();
    String? message;
    if (text.isEmpty) {
      message = 'Please enter or upload text first';
    } else if (text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length < 5) {
      message = 'Text is too short. Add at least 5 words.';
    } else if (text.length > 12000) {
      message = 'Text too long. Please reduce to under 12,000 characters.';
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
    final sessions = vm.recentSessions
        .where((s) => s.type == SessionType.grammar)
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RecentSessionsSheet(
        sessions: sessions,
        onSessionSelected: (session) {
          vm.loadSession(session);
          _ctrl.text = session.originalInput;
          setState(() {});
        },
        onSessionDeleted: vm.deleteSession,
        onSessionFavoriteToggle: vm.toggleSessionFavorite,
      ),
    );
  }

  Future<void> _exportCorrectedPdf(String text) async {
    final file = await PdfService.generateFromRichText(
      title: 'Grammar_Corrected',
      content: text,
      author: 'BrainUp AI',
      theme: PdfTheme.academic,
    );
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AiViewModel>();
    final hasSessions = vm.recentSessions.any((s) => s.type == SessionType.grammar);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
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
                  const Icon(Icons.spellcheck_rounded, color: AppColors.success, size: 22),
                  const SizedBox(width: 8),
                  Text('Grammar Check', style: AppTextStyles.h3),
                  const Spacer(),
                  if (hasSessions)
                    IconButton(
                      onPressed: _showRecentSessions,
                      icon: const Icon(
                        Icons.history_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (vm.grammarState == AiState.done)
                    IconButton(
                      onPressed: () {
                        _ctrl.clear();
                        vm.clearGrammar();
                      },
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.textSecondary),
                      tooltip: 'Reset',
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
                    InputSelector(
                      hintText: 'Enter text to check grammar...',
                      textCtrl: _ctrl,
                      onFileSelected: (file) async {
                        if (file == null) return;
                        await vm.uploadFile(file);
                        if (mounted && vm.currentInput.isNotEmpty) {
                          _ctrl.text = vm.currentInput;
                        }
                      },
                      onInputChanged: vm.setCurrentInput,
                    ),
                    const SizedBox(height: 14),
                    BrainUpButton(
                      label: 'Check Grammar',
                      isLoading: vm.grammarState == AiState.loading,
                      onTap: vm.grammarState == AiState.loading ||
                              _ctrl.text.trim().isEmpty
                          ? null
                          : () {
                              if (_validate()) {
                                vm.checkGrammar(_ctrl.text.trim());
                              }
                            },
                      icon: const Icon(Icons.spellcheck_rounded, color: Colors.white, size: 18),
                    ),
                    if (vm.grammarState == AiState.loading) ...[
                      const SizedBox(height: 20),
                      const ShimmerList(count: 2),
                    ],
                    if (vm.grammarState == AiState.error) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(vm.error ?? 'Error occurred', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                      ),
                    ],
                    if (vm.grammarState == AiState.done) ...[
                      const SizedBox(height: 20),
                      BrainUpCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text('Comparison View', style: AppTextStyles.h5),
                              const Spacer(),
                              IconButton(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: vm.grammarCorrected),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Corrected text copied'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _exportCorrectedPdf(vm.grammarCorrected),
                                icon:
                                    const Icon(Icons.download_rounded, size: 18),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Share.share(vm.grammarCorrected),
                                icon: const Icon(Icons.share_rounded, size: 18),
                              ),
                            ]),
                            const Divider(color: AppColors.surfaceBorder, height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _CompareColumn(
                                    title: 'Original',
                                    titleColor: AppColors.error,
                                    text: vm.grammarOriginal,
                                    background: AppColors.error.withOpacity(0.06),
                                    border: AppColors.error.withOpacity(0.2),
                                    underline: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _CompareColumn(
                                    title: 'Corrected',
                                    titleColor: AppColors.success,
                                    text: vm.grammarCorrected,
                                    background: AppColors.success.withOpacity(0.06),
                                    border: AppColors.success.withOpacity(0.2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (vm.grammarErrorDetails.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: BrainUpCard(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.check_circle_rounded,
                                      color: AppColors.success, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'No grammar errors found! Great writing.',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.success),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (vm.grammarErrorDetails.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        BrainUpCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Detected Errors (${vm.grammarErrorDetails.length})', style: AppTextStyles.h5),
                                ],
                              ),
                              const Divider(color: AppColors.surfaceBorder, height: 16),
                              ...vm.grammarErrorDetails.asMap().entries.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 5),
                                      width: 6, height: 6,
                                      decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _ErrorTypeBadge(issue: e.value.issue),
                                          Text(
                                            e.value.issue,
                                            style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ).animate(delay: (e.key * 40).ms).fadeIn(duration: 300.ms),
                              )),
                            ],
                          ),
                        ),
                      ],
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

class _CompareColumn extends StatelessWidget {
  final String title;
  final Color titleColor;
  final String text;
  final Color background;
  final Color border;
  final bool underline;

  const _CompareColumn({
    required this.title,
    required this.titleColor,
    required this.text,
    required this.background,
    required this.border,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              height: 1.6,
              decoration: underline ? TextDecoration.underline : null,
              decorationColor: AppColors.error.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorTypeBadge extends StatelessWidget {
  final String issue;

  const _ErrorTypeBadge({required this.issue});

  @override
  Widget build(BuildContext context) {
    final lower = issue.toLowerCase();
    Color color = AppColors.textSecondary;
    String label = 'Grammar';
    if (lower.contains('spell')) {
      color = AppColors.error;
      label = 'Spelling';
    } else if (lower.contains('tense') ||
        lower.contains('past') ||
        lower.contains('future')) {
      color = AppColors.info;
      label = 'Tense Error';
    } else if (lower.contains('article') ||
        lower.contains('a/an') ||
        lower.contains(' the ')) {
      color = AppColors.accent;
      label = 'Article Error';
    } else if (lower.contains('punct') ||
        lower.contains('period') ||
        lower.contains('apostrophe')) {
      color = AppColors.warning;
      label = 'Punctuation';
    } else if (lower.contains('comma')) {
      color = AppColors.warning;
      label = 'Missing Comma';
    } else if (lower.contains('subject') || lower.contains('verb')) {
      color = AppColors.error;
      label = 'Subject-Verb';
    } else if (lower.contains('capital') || lower.contains('uppercase')) {
      color = AppColors.info;
      label = 'Capitalization';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}
