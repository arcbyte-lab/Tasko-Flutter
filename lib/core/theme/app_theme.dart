import 'package:flutter/material.dart';

/// Light-theme tokens from modern-minimal.css, in the hex the hifi frames use
/// (arcbyte: ideas/tasko/hipster/hifi-mockup-tickets-for-pen-dev.md).
// ponytail: light only; the CSS has a .dark theme, add it as a ThemeExtension
// when dark mode is drawn.
abstract final class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF333333);
  static const mutedForeground = Color(0xFF6B7280);
  static const muted = Color(0xFFF9FAFB);
  static const secondary = Color(0xFFF3F4F6);
  static const secondaryForeground = Color(0xFF4B5563);
  static const accent = Color(0xFFE0F2FE);
  static const accentForeground = Color(0xFF1E3A8A);
  static const primary = Color(0xFF3B82F6);
  static const destructive = Color(0xFFEF4444);
  static const border = Color(0xFFE5E7EB);
  static const heatmapEmpty = Color(0xFFD7D7D9);
  static const heatmapBusiest = Color(0xFF1E40AF);
  static const controlBorder = Color(0xFFD1D5DB);
  static const placeholder = Color(0xFF9CA3AF);
}

const fontMono = 'JetBrainsMono';

/// Group labels: "WORKSPACES", "OVERDUE", "MONTHLY".
TextStyle groupLabelStyle({Color color = AppColors.mutedForeground}) =>
    TextStyle(
      fontFamily: fontMono,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: color.withValues(alpha: 0.5),
    );

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.background,
    onSurface: AppColors.foreground,
    error: AppColors.destructive,
    outline: AppColors.border,
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.border,
    thickness: 1,
    space: 1,
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.foreground,
    contentTextStyle: const TextStyle(fontSize: 15, color: Colors.white),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  ),
);
