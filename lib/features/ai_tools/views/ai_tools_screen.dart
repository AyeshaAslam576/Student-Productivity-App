import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_card.dart';

class AiToolsScreen extends StatelessWidget {
  const AiToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Tools', style: AppTextStyles.h3),
                  Text('Powered by Groq · llama3-70b', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.88,
                  children: [
                    _AiToolCard(
                      icon: Icons.summarize_rounded,
                      title: 'AI Summarizer',
                      description: 'Summarize any text or document instantly',
                      color: AppColors.accent,
                      onTap: () => context.push('/ai/summarizer'),
                    ).animate(delay: 0.ms).fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
                    _AiToolCard(
                      icon: Icons.spellcheck_rounded,
                      title: 'Grammar Check',
                      description: 'Fix grammar and improve your writing',
                      color: AppColors.success,
                      onTap: () => context.push('/ai/grammar'),
                    ).animate(delay: 60.ms).fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
                    _AiToolCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'AI Chatbot',
                      description: 'Ask anything academic',
                      color: AppColors.info,
                      onTap: () => context.push('/ai/chatbot'),
                    ).animate(delay: 120.ms).fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
                    _AiToolCard(
                      icon: Icons.record_voice_over_rounded,
                      title: 'Text to Speech',
                      description: 'Listen to any text read aloud',
                      color: AppColors.warning,
                      onTap: () => context.push('/ai/tts'),
                    ).animate(delay: 180.ms).fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
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

class _AiToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _AiToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BrainUpCard(
      onTap: onTap,
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Text(title, style: AppTextStyles.h5),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.caption.copyWith(height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
