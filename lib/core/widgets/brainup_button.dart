import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

class BrainUpButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final BrainUpButtonStyle style;
  final double? width;
  final double height;
  final Widget? icon;
  final double borderRadius;

  const BrainUpButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.style = BrainUpButtonStyle.primary,
    this.width,
    this.height = 52,
    this.icon,
    this.borderRadius = AppSpacing.radiusMd,
  });

  const BrainUpButton.secondary({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.width,
    this.height = 52,
    this.icon,
    this.borderRadius = AppSpacing.radiusMd,
  }) : style = BrainUpButtonStyle.secondary;

  const BrainUpButton.small({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.width,
    this.height = 36,
    this.icon,
    this.borderRadius = AppSpacing.radiusSm,
  }) : style = BrainUpButtonStyle.small;

  @override
  State<BrainUpButton> createState() => _BrainUpButtonState();
}

class _BrainUpButtonState extends State<BrainUpButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _scaleController.reverse();
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null && !widget.isLoading;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: isDisabled ? null : _handleTapDown,
        onTapUp: isDisabled ? null : _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: _buildButton(isDisabled),
      ),
    );
  }

  Widget _buildButton(bool isDisabled) {
    switch (widget.style) {
      case BrainUpButtonStyle.primary:
        return _PrimaryButton(
          label: widget.label,
          isLoading: widget.isLoading,
          isDisabled: isDisabled,
          width: widget.width,
          height: widget.height,
          icon: widget.icon,
          borderRadius: widget.borderRadius,
        );
      case BrainUpButtonStyle.secondary:
        return _SecondaryButton(
          label: widget.label,
          isLoading: widget.isLoading,
          isDisabled: isDisabled,
          width: widget.width,
          height: widget.height,
          icon: widget.icon,
          borderRadius: widget.borderRadius,
        );
      case BrainUpButtonStyle.small:
        return _SmallButton(
          label: widget.label,
          isLoading: widget.isLoading,
          isDisabled: isDisabled,
          width: widget.width,
          height: widget.height,
          icon: widget.icon,
          borderRadius: widget.borderRadius,
        );
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double height;
  final Widget? icon;
  final double borderRadius;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.isDisabled,
    this.width,
    required this.height,
    this.icon,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDisabled ? null : colors.accentGradient,
          color: isDisabled ? colors.surfaceElevated : null,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: context.text.button.copyWith(
                        color: isDisabled ? colors.textMuted : Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double height;
  final Widget? icon;
  final double borderRadius;

  const _SecondaryButton({
    required this.label,
    required this.isLoading,
    required this.isDisabled,
    this.width,
    required this.height,
    this.icon,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDisabled ? colors.surfaceBorder : colors.accent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.accent,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: context.text.button.copyWith(
                        color:
                            isDisabled ? colors.textMuted : colors.accent,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double height;
  final Widget? icon;
  final double borderRadius;

  const _SmallButton({
    required this.label,
    required this.isLoading,
    required this.isDisabled,
    this.width,
    required this.height,
    this.icon,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: isDisabled ? null : colors.accentGradient,
        color: isDisabled ? colors.surfaceElevated : null,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: context.text.button.copyWith(
                      fontSize: 13,
                      color: isDisabled ? colors.textMuted : Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

enum BrainUpButtonStyle { primary, secondary, small }
