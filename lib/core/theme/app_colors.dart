import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Ocean Deep palette
  static const Color primary = Color(0xFF0A2540); // Deep ocean navy
  static const Color primaryLight = Color(0xFF1A3A5C);
  static const Color accent = Color(0xFF00C2FF); // Electric ocean blue
  static const Color accentSoft = Color(0x1A00C2FF); // 10% opacity accent

  // Surfaces (dark theme — premium feel)
  static const Color surface = Color(0xFF0D1B2A); // Deepest ocean
  static const Color surfaceCard = Color(0xFF112233); // Card background
  static const Color surfaceElevated = Color(0xFF162D44); // Elevated elements
  static const Color surfaceBorder = Color(0xFF1E3A52); // Subtle borders

  // Status colors
  static const Color success = Color(0xFF00D9A3); // Teal green
  static const Color warning = Color(0xFFFFB946); // Warm amber
  static const Color error = Color(0xFFFF5A7D); // Coral red
  static const Color info = Color(0xFF6C8EFF); // Soft purple-blue

  // Subject tag colors (for subject pills)
  static const List<Color> subjectColors = [
    Color(0xFF00C2FF),
    Color(0xFF00D9A3),
    Color(0xFFFFB946),
    Color(0xFFFF5A7D),
    Color(0xFF6C8EFF),
    Color(0xFFFF8C42),
    Color(0xFFB8FF57),
    Color(0xFFFF57EE),
  ];

  // Text
  static const Color textPrimary = Color(0xFFF0F4F8);
  static const Color textSecondary = Color(0xFF8BA3B8);
  static const Color textMuted = Color(0xFF4A6580);

  // Shimmer
  static const Color shimmerBase = Color(0xFF112233);
  static const Color shimmerHighlight = Color(0xFF1E3A52);

  // Gradient stops
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A2540), Color(0xFF0D3B6E)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C2FF), Color(0xFF0080FF)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF112233), Color(0xFF0D1E30)],
  );

  // ── Light theme — Azure Mist ──────────────────────────────────────────────
  // Crisp white cards on a faintly blue-tinted background; royal-blue accent.
  static const Color lightPrimary = Color(0xFF0B3D91); // deep azure
  static const Color lightAccent = Color(0xFF2D6CDF); // vibrant action blue
  static const Color lightAccentSoft = Color(0x1A2D6CDF); // 10% accent

  static const Color lightSurface = Color(0xFFF5F8FD); // screen bg (white w/ blue whisper)
  static const Color lightSurfaceCard = Color(0xFFFFFFFF); // pure white cards
  static const Color lightSurfaceElevated = Color(0xFFEDF3FC);
  static const Color lightSurfaceBorder = Color(0xFFDCE6F5); // soft blue-grey

  static const Color lightSuccess = Color(0xFF1B9F6A);
  static const Color lightWarning = Color(0xFFE0A82E);
  static const Color lightError = Color(0xFFE04F5F);
  static const Color lightInfo = Color(0xFF3F8CFF);

  static const Color lightTextPrimary = Color(0xFF0B1F3A); // near-black w/ blue undertone
  static const Color lightTextSecondary = Color(0xFF475873); // slate
  static const Color lightTextMuted = Color(0xFF8FA0BA);

  static const Color lightShimmerBase = Color(0xFFE4EBF6);
  static const Color lightShimmerHighlight = Color(0xFFF2F6FB);

  static const LinearGradient lightPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B3D91), Color(0xFF1F5DD1)],
  );

  static const LinearGradient lightAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D6CDF), Color(0xFF4A8DF5)],
  );

  static const LinearGradient lightCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF0F5FE)],
  );

  // Helper to get subject color by name hash
  static Color subjectColor(String subjectName) {
    final index = subjectName.hashCode.abs() % subjectColors.length;
    return subjectColors[index];
  }
}
