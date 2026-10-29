import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models.dart';

/// Workspaces (`private`, divisions), then projects, each group under its
/// label; scrolls sideways (arcbyte decision 0002). Keeps the active tab in
/// view when it changes from a swipe on the list. The underline sits at
/// [position], so it slides and stretches between tabs with the pages.
/// "+ new project" ends the strip when [onNewProject] is set (decision 0011).
class TabStrip extends StatefulWidget {
  const TabStrip({
    super.key,
    required this.tabs,
    required this.active,
    required this.position,
    required this.onSelect,
    this.onNewProject,
  });

  final List<TaskTab> tabs;
  final TaskTab? active;

  /// The page position: 0 is the first tab, 1.5 halfway to the third.
  final ValueListenable<double> position;
  final ValueChanged<TaskTab> onSelect;
  final VoidCallback? onNewProject;

  @override
  State<TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<TabStrip> {
  final _keys = <TaskTab, GlobalKey>{};
  final _content = GlobalKey();

  @override
  void didUpdateWidget(TabStrip old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tab = _keys[widget.active]?.currentContext;
      if (tab != null && tab.mounted) {
        Scrollable.ensureVisible(
          tab,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.tabs.where((t) => t.kind == TabKind.myTasks).toList();
    final workspaces = widget.tabs
        .where((t) => t.kind == TabKind.private || t.kind == TabKind.division)
        .toList();
    final projects = widget.tabs
        .where((t) => t.kind == TabKind.project)
        .toList();

    Widget group(
      String label,
      List<TaskTab> items, {
      Widget? end,
      bool hideLabel = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 10),
          // A hidden label still takes its line, so the tabs line up.
          child: Opacity(
            opacity: hideLabel ? 0 : 1,
            child: ExcludeSemantics(
              excluding: hideLabel,
              child: Text(label, style: groupLabelStyle()),
            ),
          ),
        ),
        Row(
          children: [
            for (final t in items)
              _Tab(
                t,
                t == widget.active,
                widget.onSelect,
                key: _keys.putIfAbsent(t, GlobalKey.new),
              ),
            ?end,
          ],
        ),
      ],
    );

    // Built before the painter, which reads the keys the tabs create.
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "my tasks" first, with no group label (decision 0017).
        if (mine.isNotEmpty) group('MY TASKS', mine, hideLabel: true),
        if (workspaces.isNotEmpty) group('WORKSPACES', workspaces),
        // Shown with no projects yet too, so a lead can make the first one.
        if (projects.isNotEmpty || widget.onNewProject != null)
          group(
            'PROJECTS',
            projects,
            end: widget.onNewProject == null
                ? null
                : _NewProject(widget.onNewProject!),
          ),
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
        child: CustomPaint(
          key: _content,
          foregroundPainter: _Indicator(
            position: widget.position,
            content: _content,
            tabs: [for (final t in widget.tabs) _keys[t]],
          ),
          child: row,
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.tab, this.active, this.onSelect, {super.key});

  final TaskTab tab;
  final bool active;
  final ValueChanged<TaskTab> onSelect;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    button: true,
    child: InkWell(
      onTap: () => onSelect(tab),
      // The underline is painted under the tab by _Indicator.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
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

class _NewProject extends StatelessWidget {
  const _NewProject(this.onTap);

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'New project',
    child: InkWell(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(8, 6, 8, 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: AppColors.mutedForeground),
            SizedBox(width: 4),
            Text(
              'new project',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The 2px primary underline, between the tabs either side of [position]:
/// it moves and resizes from one tab's width to the next as the pages move.
class _Indicator extends CustomPainter {
  _Indicator({
    required this.position,
    required this.content,
    required this.tabs,
  }) : super(repaint: position);

  final ValueListenable<double> position;
  final GlobalKey content;

  /// Each tab's key, in page order.
  final List<GlobalKey?> tabs;

  /// [key]'s box inside the strip's content, or null before layout.
  Rect? _rect(GlobalKey? key) {
    final tab = key?.currentContext?.findRenderObject() as RenderBox?;
    final root = content.currentContext?.findRenderObject() as RenderBox?;
    if (tab == null || root == null || !tab.attached) return null;
    return tab.localToGlobal(Offset.zero, ancestor: root) & tab.size;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (tabs.isEmpty) return;
    final p = position.value.clamp(0, tabs.length - 1).toDouble();
    final i = p.floor();
    final a = _rect(tabs[i]);
    final b = _rect(tabs[(i + 1).clamp(0, tabs.length - 1)]);
    if (a == null || b == null) return;
    final r = Rect.lerp(a, b, p - i)!;
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.bottom - 2, r.width, 2),
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_Indicator old) => true; // tab boxes may have moved
}
