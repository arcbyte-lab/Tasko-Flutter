import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/toast.dart';

/// The rails dock of hifi H13: a 100px bar with a 16px blur and a 50% white
/// fill, holding navigations on the left and actions on the right. It
/// replaces the FAB. Media and Discussion are out of this cycle, so
/// they only toast; tapping Home does nothing, it is the screen you are on.
class Rails extends StatelessWidget {
  const Rails({
    super.key,
    required this.onNewTask,
    this.onNewProject,
    this.navigations = true,
  });

  /// My Workspace shows only the actions, over its grabber strip.
  final bool navigations;

  final VoidCallback onNewTask;
  final VoidCallback? onNewProject;

  @override
  Widget build(BuildContext context) {
    void soon(String name) => showToast(context, '$name is not available yet');
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 100,
          color: Colors.white.withValues(alpha: 0.5),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          alignment: Alignment.topCenter,
          child: Row(
            children: [
              if (!navigations)
                const Spacer(flex: 3)
              else
                Flexible(
                  flex: 3,
                  child: _Rail([
                    const _Item(
                      Icons.home_outlined,
                      'Home',
                      active: true,
                      width: 76,
                    ),
                    _Item(
                      Icons.view_in_ar_outlined,
                      'Media',
                      onTap: () => soon('Media'),
                      width: 76,
                    ),
                    _Item(
                      Icons.chat_bubble_outline,
                      'Discussion',
                      onTap: () => soon('Discussion'),
                      width: 76,
                    ),
                  ]),
                ),
              const SizedBox(width: 9),
              Flexible(
                flex: 2,
                child: _Rail([
                  if (onNewProject != null)
                    _Item(
                      Icons.dashboard_customize_outlined,
                      'New project',
                      onTap: onNewProject,
                    ),
                  _Item(Icons.note_add_outlined, 'New task', onTap: onNewTask),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail(this.items);
  final List<_Item> items;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final i in items) Flexible(child: i)],
        ),
      ),
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item(
    this.icon,
    this.label, {
    this.active = false,
    this.onTap,
    this.width = 70,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF1E3A8A) : AppColors.mutedForeground;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: width,
            minHeight: 44,
            maxHeight: 44,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE0F2FE) : null,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 8, color: color),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
