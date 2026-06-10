import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
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
    final data = _variantData(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.hasBoundedHeight &&
                constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildIllustration(data.icon, data.color),
                  const SizedBox(height: 24),
                  Text(
                    title ?? data.title,
                    style: context.text.h4,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle ?? data.subtitle,
                    style: context.text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 16),
                    BrainUpButton(
                      label: actionLabel!,
                      onTap: onAction,
                      width: 220,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIllustration(IconData icon, Color color) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Icon(icon, size: 48, color: color),
      ),
    );
  }

  _EmptyData _variantData(BuildContext context) {
    final colors = context.colors;
    switch (variant) {
      case EmptyStateVariant.tasks:
        return _EmptyData(
          icon: Icons.check_circle_outline_rounded,
          color: colors.success,
          title: 'No tasks yet',
          subtitle: 'Add your first task to get started',
        );
      case EmptyStateVariant.timetable:
        return _EmptyData(
          icon: Icons.calendar_month_outlined,
          color: colors.accent,
          title: 'No timetable set up',
          subtitle: 'Upload your timetable image or add classes manually',
        );
      case EmptyStateVariant.cgpa:
        return _EmptyData(
          icon: Icons.school_outlined,
          color: colors.info,
          title: 'No semesters added',
          subtitle: 'Start tracking your CGPA by adding a semester',
        );
      case EmptyStateVariant.attendance:
        return _EmptyData(
          icon: Icons.how_to_reg_outlined,
          color: colors.warning,
          title: 'No attendance records',
          subtitle: 'Mark attendance for your lectures to track here',
        );
      case EmptyStateVariant.generic:
        return _EmptyData(
          icon: Icons.inbox_outlined,
          color: colors.textMuted,
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
