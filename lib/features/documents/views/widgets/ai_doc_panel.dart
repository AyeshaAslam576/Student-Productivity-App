import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/brainup_button.dart';
import '../../services/doc_ai_service.dart';

class AiDocPanel extends StatelessWidget {
  final bool isAnalyzing;
  final DocAiAnalysis? analysis;
  final VoidCallback onAnalyze;
  final VoidCallback? onCreateTasks;

  const AiDocPanel({
    super.key,
    required this.isAnalyzing,
    required this.analysis,
    required this.onAnalyze,
    this.onCreateTasks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: analysis == null
            ? BrainUpButton(
                label: isAnalyzing ? 'Analyzing...' : 'Analyze Document',
                isLoading: isAnalyzing,
                onTap: isAnalyzing ? null : onAnalyze,
              )
            : ListView(
                children: [
                  Row(
                    children: [
                      Text('Summary', style: AppTextStyles.h5),
                      const Spacer(),
                      _DifficultyBadge(level: analysis!.difficulty),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(analysis!.summary, style: AppTextStyles.body),
                  const SizedBox(height: 14),
                  Text('Key Topics', style: AppTextStyles.h5),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: analysis!.keyTopics
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(t, style: AppTextStyles.caption),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Important Dates', style: AppTextStyles.h5),
                  const SizedBox(height: 8),
                  ...analysis!.importantDates.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.label}: ${item.date}',
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Suggested Tasks', style: AppTextStyles.h5),
                  const SizedBox(height: 8),
                  ...analysis!.suggestedTasks.map(
                    (task) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task.title, style: AppTextStyles.bodySmall),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _priorityColor(task.priority)
                                        .withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    task.priority.toUpperCase(),
                                    style: AppTextStyles.caption.copyWith(
                                      color: _priorityColor(task.priority),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: onCreateTasks,
                            child: const Text('Add Task'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Study Tips', style: AppTextStyles.h5),
                  const SizedBox(height: 8),
                  ...analysis!.studyTips.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${entry.key + 1}. ${entry.value}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Color _priorityColor(String value) {
    switch (value.toLowerCase()) {
      case 'high':
      case 'critical':
        return AppColors.error;
      case 'low':
        return AppColors.success;
      case 'medium':
      default:
        return AppColors.warning;
    }
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String level;

  const _DifficultyBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final lower = level.toLowerCase();
    final color = switch (lower) {
      'easy' => AppColors.success,
      'hard' => AppColors.error,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level[0].toUpperCase() + level.substring(1),
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}
