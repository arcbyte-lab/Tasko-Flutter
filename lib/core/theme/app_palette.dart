import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The colours that flip on My Workspace, the one dark screen (hifi H13).
/// Everything else keeps [AppColors]; a widget reads [AppPalette.of] only
/// where it is drawn on both.
// ponytail: four colours, not a dark ThemeData; widen it if more screens go dark.
class AppPalette {
  const AppPalette({
    required this.foreground,
    required this.muted,
    required this.border,
    required this.control,
    required this.background,
    this.isDark = false,
  });

  final Color foreground;
  final Color muted;
  final Color border;
  final Color control;
  final Color background;

  /// Badges and other drawn colours pick their dark look from this.
  final bool isDark;

  static const light = AppPalette(
    foreground: AppColors.foreground,
    muted: AppColors.mutedForeground,
    border: AppColors.border,
    control: AppColors.controlBorder,
    background: Colors.white,
  );

  static const dark = AppPalette(
    foreground: Color(0xFFF3F4F6),
    muted: Color(0xFF9CA3AF),
    border: Color(0xFF27272A),
    control: Color(0xFF52525B),
    background: Colors.black,
    isDark: true,
  );

  static AppPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaletteScope>()?.palette ??
      light;
}

class PaletteScope extends InheritedWidget {
  const PaletteScope({super.key, required this.palette, required super.child});

  final AppPalette palette;

  @override
  bool updateShouldNotify(PaletteScope old) => palette != old.palette;
}
