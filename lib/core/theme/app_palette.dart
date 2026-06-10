import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Theme-aware color palette resolved from a [BuildContext].
///
/// Access via `context.colors.accent`. Picks dark or light variant based on
/// `Theme.of(context).brightness`, so screens automatically adapt when the
/// user switches themes (or system theme changes).
class AppPalette {
  final Brightness _b;
  const AppPalette._(this._b);

  factory AppPalette.of(BuildContext context) =>
      AppPalette._(Theme.of(context).brightness);

  bool get isDark => _b == Brightness.dark;

  // ── Primary / accent ─────────────────────────────────────────────────────
  Color get primary => isDark ? AppColors.primary : AppColors.lightPrimary;
  Color get primaryLight =>
      isDark ? AppColors.primaryLight : AppColors.lightPrimary;
  Color get accent => isDark ? AppColors.accent : AppColors.lightAccent;
  Color get accentSoft =>
      isDark ? AppColors.accentSoft : AppColors.lightAccentSoft;

  // ── Surfaces ─────────────────────────────────────────────────────────────
  Color get surface => isDark ? AppColors.surface : AppColors.lightSurface;
  Color get surfaceCard =>
      isDark ? AppColors.surfaceCard : AppColors.lightSurfaceCard;
  Color get surfaceElevated =>
      isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated;
  Color get surfaceBorder =>
      isDark ? AppColors.surfaceBorder : AppColors.lightSurfaceBorder;

  // ── Status colors ────────────────────────────────────────────────────────
  Color get success => isDark ? AppColors.success : AppColors.lightSuccess;
  Color get warning => isDark ? AppColors.warning : AppColors.lightWarning;
  Color get error => isDark ? AppColors.error : AppColors.lightError;
  Color get info => isDark ? AppColors.info : AppColors.lightInfo;

  // ── Text ─────────────────────────────────────────────────────────────────
  Color get textPrimary =>
      isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get textMuted =>
      isDark ? AppColors.textMuted : AppColors.lightTextMuted;

  // ── Shimmer ──────────────────────────────────────────────────────────────
  Color get shimmerBase =>
      isDark ? AppColors.shimmerBase : AppColors.lightShimmerBase;
  Color get shimmerHighlight =>
      isDark ? AppColors.shimmerHighlight : AppColors.lightShimmerHighlight;

  // ── Gradients ────────────────────────────────────────────────────────────
  LinearGradient get primaryGradient =>
      isDark ? AppColors.primaryGradient : AppColors.lightPrimaryGradient;
  LinearGradient get accentGradient =>
      isDark ? AppColors.accentGradient : AppColors.lightAccentGradient;
  LinearGradient get cardGradient =>
      isDark ? AppColors.cardGradient : AppColors.lightCardGradient;

  // ── Subject colors (palette is theme-agnostic) ───────────────────────────
  List<Color> get subjectColors => AppColors.subjectColors;
  Color subjectColor(String name) => AppColors.subjectColor(name);

  // ── Overlay helpers used by status bar / scrims ──────────────────────────
  /// Onscreen scrim color for full-screen overlays (e.g. progress).
  Color get scrim => Colors.black.withValues(alpha: isDark ? 0.55 : 0.35);
}

/// Theme-aware text styles resolved from a [BuildContext].
///
/// Access via `context.text.h4`. Colors auto-switch between dark/light. Sizes
/// and weights stay constant.
class AppTextPalette {
  final AppPalette _p;
  const AppTextPalette._(this._p);

  factory AppTextPalette.of(BuildContext context) =>
      AppTextPalette._(AppPalette.of(context));

  TextStyle get _base => GoogleFonts.plusJakartaSans();

  TextStyle get display => _base.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: _p.textPrimary,
        letterSpacing: -1.0,
      );

  TextStyle get h1 => _base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: _p.textPrimary,
        letterSpacing: -0.5,
      );

  TextStyle get h2 => _base.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: _p.textPrimary,
        letterSpacing: -0.3,
      );

  TextStyle get h3 => _base.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: _p.textPrimary,
      );

  TextStyle get h4 => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _p.textPrimary,
      );

  TextStyle get h5 => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _p.textPrimary,
      );

  TextStyle get bodyLarge => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: _p.textPrimary,
      );

  TextStyle get body => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _p.textPrimary,
      );

  TextStyle get bodySmall => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _p.textSecondary,
      );

  TextStyle get label => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _p.textSecondary,
        letterSpacing: 0.5,
      );

  TextStyle get labelSmall => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _p.textSecondary,
        letterSpacing: 0.5,
      );

  TextStyle get caption => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: _p.textMuted,
      );

  TextStyle get button => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.3,
      );

  TextStyle get accentText => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _p.accent,
      );

  TextStyle get monospace => TextStyle(
        fontFamily: 'monospace',
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: _p.textPrimary,
        letterSpacing: 2,
      );
}

extension BrainUpThemeContext on BuildContext {
  /// Theme-aware palette resolved from this context.
  AppPalette get colors => AppPalette.of(this);

  /// Theme-aware text styles resolved from this context.
  AppTextPalette get text => AppTextPalette.of(this);
}
