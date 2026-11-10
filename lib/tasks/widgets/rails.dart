import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/toast.dart';

/// The two floating rails of hifi H13: navigations on the left, actions on the
/// right. They replace the FAB. Media and Discussion are out of this cycle, so
/// they only toast; tapping Home does nothing, it is the screen you are on.
class Rails extends StatelessWidget {
  const Rails({super.key, required this.onNewTask, this.onNewProject});

  final VoidCallback onNewTask;
  final VoidCallback? onNewProject;

  @override
  Widget build(BuildContext context) {
    void soon(String name) => showToast(context, '$name is not available yet');
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 19.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Rail([
              const _Item(Icons.home_outlined, 'Home', active: true),
              _Item(
                Icons.perm_media_outlined,
                'Media',
                onTap: () => soon('Media'),
              ),
              _Item(
                Icons.chat_bubble_outline,
                'Discussion',
                onTap: () => soon('Discussion'),
              ),
            ]),
            _Rail([
              if (onNewProject != null)
                _Item(
                  Icons.create_new_folder_outlined,
                  'New project',
                  onTap: onNewProject,
                ),
              _Item(Icons.add, 'New task', onTap: onNewTask),
            ]),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: items),
      ),
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, {this.active = false, this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF1E3A8A) : AppColors.mutedForeground;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 56,
          height: 44,
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
                label,
                style: TextStyle(fontSize: 9, color: color),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
