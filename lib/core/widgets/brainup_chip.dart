import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

class BrainUpChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? selectedColor;
  final IconData? icon;

  const BrainUpChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.selectedColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selectedColor ?? colors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.6)
                : colors.surfaceBorder,
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? color : colors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: context.text.labelSmall.copyWith(
                color: isSelected ? color : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrainUpChipGroup extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onChanged;
  final Color? selectedColor;

  const BrainUpChipGroup({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: BrainUpChip(
              label: item,
              isSelected: selected == item,
              onTap: () => onChanged(item),
              selectedColor: selectedColor,
            ),
          );
        }).toList(),
      ),
    );
  }
}
