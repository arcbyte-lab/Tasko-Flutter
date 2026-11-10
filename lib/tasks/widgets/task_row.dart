import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../models.dart';
import '../task_rules.dart';
import 'task_badges.dart';

/// The task row of hifi H1 (the pen file's `hifi / Task Row`, 62 tall): the
/// assignee's avatar, then two lines. Line 1: the title and the due date
/// ("Overdue Oct 3" in red). Line 2: the task code and where the task lives
/// ("TECH-0141 · tech"), the priority badge, and the status badge on the right.
/// There is no checkbox: a task is moved on in Task Detail.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.now,
    required this.onTap,
    this.assignee,
    this.mine = false,
    this.tabName,
  });

  final Task task;
  final DateTime now;

  /// Opens Task Detail.
  final VoidCallback onTap;

  /// Whoever the task is assigned to, or the viewer for a personal task.
  /// Null when nobody.
  final User? assignee;

  /// [assignee] is the viewer: a solid blue avatar.
  final bool mine;

  /// Where the task lives: its division or project, after the code.
  final String? tabName;

  static Color priorityColor(
    Priority p, [
    AppPalette palette = AppPalette.light,
  ]) => switch (p) {
    Priority.urgent => AppColors.destructive,
    Priority.high => palette.foreground,
    Priority.medium || Priority.low => palette.muted,
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final done = task.status == TaskStatus.done;
    final overdue = isOverdue(task, now);
    final due = task.dueDate;
    final dateText = due == null
        ? ''
        : '${overdue ? 'Overdue ' : ''}${shortDate(due, now)}';
    // "TECH-0141 · tech": the code, then where the task lives (a division or a
    // project), with a space each side of the dot.
    final idText = [?task.code, ?tabName].join(' · ');
    final small = TextStyle(fontSize: 12, height: 15 / 12, color: p.muted);

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        // 62 tall with the 1px line, as in the pen.
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 9),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: Row(
          spacing: 12,
          children: [
            TaskAvatar(assignee, mine: mine),
            Expanded(
              child: Column(
                spacing: 4,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, box) => Row(
                      spacing: 4,
                      children: [
                        Expanded(
                          child: Text(
                            task.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              height: 19 / 15,
                              color: done ? p.muted : p.foreground,
                            ),
                          ),
                        ),
                        if (dateText.isNotEmpty)
                          // A long date gives way to the title past half the line.
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: box.maxWidth / 2,
                            ),
                            child: Text(
                              dateText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: overdue
                                  ? small.copyWith(color: AppColors.destructive)
                                  : small,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      // One side takes what the status badge leaves, so the
                      // badge ends on the right edge, under the date. (A
                      // Flexible beside a Spacer would split the free space
                      // and leave half of it unused.)
                      Expanded(
                        child: Row(
                          spacing: 8,
                          children: [
                            if (idText.isNotEmpty)
                              Flexible(
                                child: Text(
                                  idText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: small,
                                ),
                              ),
                            PriorityBadge(task.priority),
                          ],
                        ),
                      ),
                      StatusBadge(task.status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 24px avatar on the left of a task row: the viewer's is solid blue,
/// anyone else's the light #E0F2FE (H0), and nobody's a grey disc.
class TaskAvatar extends StatelessWidget {
  const TaskAvatar(this.user, {super.key, this.mine = false});

  final User? user;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: u == null
            ? AppColors.secondary
            : mine
            ? const Color(0xFF2563EB)
            : AppColors.accent,
      ),
      child: u == null
          ? const Icon(
              Icons.person_outline,
              size: 14,
              color: AppColors.mutedForeground,
            )
          : Text(
              u.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: mine ? Colors.white : AppColors.accentForeground,
              ),
            ),
    );
  }
}

/// Three looks: open, in review (lower half tinted), done (filled with ✓).
class TaskCheckbox extends StatelessWidget {
  const TaskCheckbox({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 20,
  });

  final TaskStatus status;
  final VoidCallback onTap;

  /// 20 on the list, 16 for sub-tasks. The tap target stays 44.
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final review = status == TaskStatus.review;
    final done = status == TaskStatus.done;
    return Semantics(
      checked: done,
      label: review ? 'In review' : (done ? 'Mark not done' : 'Mark done'),
      button: !review,
      excludeSemantics: true,
      child: InkResponse(
        onTap: review ? null : onTap,
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: size,
              height: size,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: done ? AppColors.primary : p.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  width: 1.5,
                  color: done || review ? AppColors.primary : p.control,
                ),
              ),
              child: done
                  ? Icon(Icons.check, size: size * 0.7, color: Colors.white)
                  : review
                  ? const Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.5,
                        widthFactor: 1,
                        child: ColoredBox(color: AppColors.accent),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
