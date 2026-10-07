import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models.dart';

/// Workspaces (`private`, divisions), then projects, each group under its
/// label; scrolls sideways (arcbyte decision 0002).
class TabStrip extends StatelessWidget {
  const TabStrip({
    super.key,
    required this.tabs,
    required this.active,
    required this.onSelect,
  });

  final List<TaskTab> tabs;
  final TaskTab? active;
  final ValueChanged<TaskTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final workspaces = tabs.where((t) => t.kind != TabKind.project).toList();
    final projects = tabs.where((t) => t.kind == TabKind.project).toList();

    Widget group(String label, List<TaskTab> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 10),
          child: Text(label, style: groupLabelStyle()),
        ),
        Row(children: [for (final t in items) _Tab(t, t == active, onSelect)]),
      ],
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (workspaces.isNotEmpty) group('WORKSPACES', workspaces),
            if (projects.isNotEmpty) group('PROJECTS', projects),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.tab, this.active, this.onSelect);

  final TaskTab tab;
  final bool active;
  final ValueChanged<TaskTab> onSelect;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    button: true,
    child: InkWell(
      onTap: () => onSelect(tab),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: active ? AppColors.primary : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          tab.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? AppColors.foreground : AppColors.mutedForeground,
          ),
        ),
      ),
    ),
  );
}
