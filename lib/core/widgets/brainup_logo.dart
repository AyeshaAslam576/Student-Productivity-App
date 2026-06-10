import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

/// App logo mark from [AppAssets.logo], sized for headers, splash, and sheets.
class BrainUpLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;

  const BrainUpLogo({
    super.key,
    required this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        AppAssets.logo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
