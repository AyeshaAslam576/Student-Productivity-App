import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum BadgePriority { high, medium, low }

enum BadgeStatus { pending, completed, overdue }

class BrainUpPriorityBadge extends StatelessWidget {
  final BadgePriority priority;

  const BrainUpPriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, color) = switch (priority) {
      BadgePriority.high => ('HIGH', colors.error),
      BadgePriority.medium => ('MED', colors.warning),
      BadgePriority.low => ('LOW', colors.success),
    };

    return _Badge(label: label, color: color);
  }

  static BadgePriority fromString(String s) {
    return switch (s.toLowerCase()) {
      'high' => BadgePriority.high,
      'medium' || 'med' => BadgePriority.medium,
      _ => BadgePriority.low,
    };
  }

  /// Theme-agnostic priority color (dark palette). Prefer `context.colors`
  /// when a [BuildContext] is available.
  static Color colorFromString(String s) {
    return switch (s.toLowerCase()) {
      'high' => AppColors.error,
      'medium' || 'med' => AppColors.warning,
      _ => AppColors.success,
    };
  }
}

class BrainUpStatusBadge extends StatelessWidget {
  final BadgeStatus status;

  const BrainUpStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, color) = switch (status) {
      BadgeStatus.pending => ('PENDING', colors.info),
      BadgeStatus.completed => ('DONE', colors.success),
      BadgeStatus.overdue => ('OVERDUE', colors.error),
    };

    return _Badge(label: label, color: color);
  }
}

class BrainUpSubjectChip extends StatelessWidget {
  final String subject;
  final bool small;

  const BrainUpSubjectChip({super.key, required this.subject, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.subjectColor(subject);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        subject,
        style: context.text.labelSmall.copyWith(
          color: color,
          fontSize: small ? 10 : 11,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class BrainUpTypeBadge extends StatelessWidget {
  final String type;

  const BrainUpTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (type.toLowerCase()) {
      'lab' => colors.warning,
      'quiz' => colors.error,
      'project' => colors.info,
      'assignment' => colors.accent,
      _ => colors.textSecondary,
    };

    return _Badge(label: type.toUpperCase(), color: color);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: context.text.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class BrainUpNotificationDot extends StatelessWidget {
  const BrainUpNotificationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: context.colors.error,
        shape: BoxShape.circle,
      ),
    );
  }
}
