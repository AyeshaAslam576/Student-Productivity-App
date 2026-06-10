import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
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
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                      Text('Summary', style: context.text.h5),
                      const Spacer(),
                      _DifficultyBadge(level: analysis!.difficulty),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(analysis!.summary, style: context.text.body),
                  const SizedBox(height: 14),
                  Text('Key Topics', style: context.text.h5),
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
                              color: colors.surfaceElevated,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(t, style: context.text.caption),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Important Dates', style: context.text.h5),
                  const SizedBox(height: 8),
                  ...analysis!.importantDates.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            color: colors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.label}: ${item.date}',
                              style: context.text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Suggested Tasks', style: context.text.h5),
                  const SizedBox(height: 8),
                  ...analysis!.suggestedTasks.map(
                    (task) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task.title,
                                    style: context.text.bodySmall),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _priorityColor(
                                            context, task.priority)
                                        .withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    task.priority.toUpperCase(),
                                    style: context.text.caption.copyWith(
                                      color:
                                          _priorityColor(context, task.priority),
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
                  Text('Study Tips', style: context.text.h5),
                  const SizedBox(height: 8),
                  ...analysis!.studyTips.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${entry.key + 1}. ${entry.value}',
                            style: context.text.bodySmall,
                          ),
                        ),
                      ),
                ],
              ),
      ),
    );
  }

  Color _priorityColor(BuildContext context, String value) {
    final colors = context.colors;
    switch (value.toLowerCase()) {
      case 'high':
      case 'critical':
        return colors.error;
      case 'low':
        return colors.success;
      case 'medium':
      default:
        return colors.warning;
    }
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String level;

  const _DifficultyBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lower = level.toLowerCase();
    final color = switch (lower) {
      'easy' => colors.success,
      'hard' => colors.error,
      _ => colors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level[0].toUpperCase() + level.substring(1),
        style: context.text.caption.copyWith(color: color),
      ),
    );
  }
}
