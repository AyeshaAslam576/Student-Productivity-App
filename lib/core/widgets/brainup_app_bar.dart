import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

class BrainUpAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showAvatar;
  final String? avatarUrl;
  final String? avatarInitials;
  final bool showBorder;
  final Color? backgroundColor;

  const BrainUpAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showAvatar = false,
    this.avatarUrl,
    this.avatarInitials,
    this.showBorder = true,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface,
        border: showBorder
            ? Border(
                bottom: BorderSide(color: colors.surfaceBorder, width: 0.5),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            if (showAvatar) ...[
              _buildAvatar(context),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.h3),
                  if (subtitle != null)
                    Text(subtitle!, style: context.text.bodySmall),
                ],
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final colors = context.colors;
    if (avatarUrl != null) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: colors.surfaceElevated,
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: colors.accentGradient,
      ),
      child: Center(
        child: Text(
          avatarInitials ?? '?',
          style: context.text.label.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
