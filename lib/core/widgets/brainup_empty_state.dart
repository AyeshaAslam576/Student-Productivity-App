import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';
import 'brainup_button.dart';

enum EmptyStateVariant { tasks, timetable, cgpa, attendance, generic }

class BrainUpEmptyState extends StatelessWidget {
  final EmptyStateVariant variant;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const BrainUpEmptyState({
    super.key,
    this.variant = EmptyStateVariant.generic,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final data = _variantData();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIllustration(data.icon, data.color),
            const SizedBox(height: 24),
            Text(
              title ?? data.title,
              style: AppTextStyles.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle ?? data.subtitle,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              BrainUpButton(
                label: actionLabel!,
                onTap: onAction,
                width: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(IconData icon, Color color) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
      ),
      child: Center(
        child: Icon(icon, size: 48, color: color),
      ),
    );
  }

  _EmptyData _variantData() {
    switch (variant) {
      case EmptyStateVariant.tasks:
        return _EmptyData(
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
          title: 'No tasks yet',
          subtitle: 'Add your first task to get started',
        );
      case EmptyStateVariant.timetable:
        return _EmptyData(
          icon: Icons.calendar_month_outlined,
          color: AppColors.accent,
          title: 'No timetable set up',
          subtitle: 'Upload your timetable image or add classes manually',
        );
      case EmptyStateVariant.cgpa:
        return _EmptyData(
          icon: Icons.school_outlined,
          color: AppColors.info,
          title: 'No semesters added',
          subtitle: 'Start tracking your CGPA by adding a semester',
        );
      case EmptyStateVariant.attendance:
        return _EmptyData(
          icon: Icons.how_to_reg_outlined,
          color: AppColors.warning,
          title: 'No attendance records',
          subtitle: 'Mark attendance for your lectures to track here',
        );
      case EmptyStateVariant.generic:
        return _EmptyData(
          icon: Icons.inbox_outlined,
          color: AppColors.textMuted,
          title: 'Nothing here yet',
          subtitle: 'Your content will appear here',
        );
    }
  }
}

class _EmptyData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  _EmptyData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
