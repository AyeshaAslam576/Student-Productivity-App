import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

class BrainUpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final LinearGradient? gradient;
  final BorderRadius? borderRadius;
  final bool showShadow;
  final Color? borderColor;

  const BrainUpCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.width,
    this.height,
    this.gradient,
    this.borderRadius,
    this.showShadow = true,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final br = borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg);
    Widget card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient ?? colors.cardGradient,
        borderRadius: br,
        border: Border.all(
          color: borderColor ?? colors.surfaceBorder,
          width: 0.5,
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          splashColor: colors.accent.withValues(alpha: 0.08),
          highlightColor: colors.accent.withValues(alpha: 0.04),
          child: card,
        ),
      );
    }

    return card;
  }
}
