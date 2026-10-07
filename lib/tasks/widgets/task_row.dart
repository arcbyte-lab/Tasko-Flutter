import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models.dart';
import '../task_rules.dart';

/// Checkbox, title, then "priority · status · due" (hifi H1 task row).
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.now,
    required this.onTick,
  });

  final Task task;
  final DateTime now;
  final VoidCallback onTick;

  static Color priorityColor(Priority p) => switch (p) {
    Priority.urgent => AppColors.destructive,
    Priority.high => AppColors.foreground,
    Priority.medium || Priority.low => AppColors.mutedForeground,
  };

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    final overdue = isOverdue(task, now);
    const meta = TextStyle(fontSize: 12, color: AppColors.mutedForeground);
    final red = meta.copyWith(color: AppColors.destructive);
    const dot = TextSpan(text: ' · ');

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
      child: Row(
        children: [
          _Checkbox(status: task.status, onTap: onTick),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: done
                        ? AppColors.mutedForeground
                        : AppColors.foreground,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: meta,
                    children: [
                      TextSpan(
                        text: task.priority.name,
                        style: meta.copyWith(
                          color: priorityColor(task.priority),
                        ),
                      ),
                      dot,
                      TextSpan(text: task.status.label),
                      if (overdue) ...[
                        dot,
                        TextSpan(text: 'overdue', style: red),
                      ],
                      if (task.dueDate != null) ...[
                        dot,
                        TextSpan(
                          text: shortDate(task.dueDate!, now),
                          style: overdue ? red : null,
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three looks: open, in review (lower half tinted), done (filled with ✓).
class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.status, required this.onTap});

  final TaskStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              width: 20,
              height: 20,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: done ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  width: 1.5,
                  color: done || review
                      ? AppColors.primary
                      : AppColors.controlBorder,
                ),
              ),
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
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
