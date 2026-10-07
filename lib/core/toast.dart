import 'dart:async';

import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

/// A snackbar-looking message drawn above every route. A SnackBar from inside
/// a modal sheet lands on the Scaffold beneath the sheet, out of sight.
void showToast(BuildContext context, String text) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 16,
      right: 16,
      bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
      child: IgnorePointer(
        child: Material(
          color: AppColors.foreground,
          elevation: 6,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Timer(const Duration(seconds: 3), entry.remove);
}
