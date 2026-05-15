import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';
import 'brainup_button.dart';

class BrainUpErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const BrainUpErrorState({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text('Something went wrong', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            Text(
              message ?? 'An unexpected error occurred. Please try again.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 28),
              BrainUpButton(
                label: 'Retry',
                onTap: onRetry,
                width: 160,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
