import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/brainup_card.dart';
import '../../models/ai_session_model.dart';

class RecentSessionsSheet extends StatelessWidget {
  final List<AiSession> sessions;
  final ValueChanged<AiSession> onSessionSelected;
  final ValueChanged<String> onSessionDeleted;
  final ValueChanged<String>? onSessionFavoriteToggle;

  const RecentSessionsSheet({
    super.key,
    required this.sessions,
    required this.onSessionSelected,
    required this.onSessionDeleted,
    this.onSessionFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  Text('Recent Sessions', style: AppTextStyles.h4),
                  const Spacer(),
                  if (sessions.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        for (final session in sessions) {
                          onSessionDeleted(session.id);
                        }
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Clear all',
                        style: TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceBorder, height: 14),
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_rounded,
                              color: AppColors.textMuted, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            'No recent sessions',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sessions.length,
                      itemBuilder: (_, index) {
                        final session = sessions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BrainUpCard(
                            onTap: () {
                              onSessionSelected(session);
                              Navigator.pop(context);
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color:
                                        _typeColor(session.type).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _typeIcon(session.type),
                                    color: _typeColor(session.type),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _typeLabel(session.type),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        session.preview,
                                        style: AppTextStyles.caption,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        session.formattedDate,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    session.isFavorite
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: session.isFavorite
                                        ? AppColors.warning
                                        : AppColors.textMuted,
                                    size: 18,
                                  ),
                                  onPressed: onSessionFavoriteToggle == null
                                      ? null
                                      : () => onSessionFavoriteToggle!(session.id),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => onSessionDeleted(session.id),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.textMuted,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(SessionType type) {
    return switch (type) {
      SessionType.summarizer => Icons.summarize_rounded,
      SessionType.grammar => Icons.spellcheck_rounded,
      SessionType.chatbot => Icons.chat_bubble_outline_rounded,
      SessionType.tts => Icons.record_voice_over_rounded,
    };
  }

  Color _typeColor(SessionType type) {
    return switch (type) {
      SessionType.summarizer => AppColors.accent,
      SessionType.grammar => AppColors.success,
      SessionType.chatbot => AppColors.info,
      SessionType.tts => AppColors.warning,
    };
  }

  String _typeLabel(SessionType type) {
    return switch (type) {
      SessionType.summarizer => 'Summarizer',
      SessionType.grammar => 'Grammar Check',
      SessionType.chatbot => 'Chatbot',
      SessionType.tts => 'Text to Speech',
    };
  }
}
