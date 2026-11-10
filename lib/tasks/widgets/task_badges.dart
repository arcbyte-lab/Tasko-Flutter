import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../models.dart';

/// The priority and status badges of the task row (hifi H1, the pen file's
/// `hifi / Task Row` and `hifi / My Workspace / Task Row`): 12 medium, radius
/// 6, padding 2/8, a 1px border. Light and dark follow the palette.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.fill,
    required this.border,
    required this.text,
    this.dot,
  });

  final String label;
  final Color fill;
  final Color border;
  final Color text;

  /// The 6px dot before the label (status badges only).
  final Color? dot;

  @override
  Widget build(BuildContext context) => Container(
    // The pen's 2/8 padding with the stroke inside: 1px less each side here.
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      color: fill,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        if (dot != null)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 15 / 12,
            color: text,
          ),
        ),
      ],
    ),
  );
}

/// Fill, border and text for one badge, in light and dark.
typedef _Look = ({Color fill, Color border, Color text, Color? dot});

_Look _look(bool dark, int fill, int border, int text, [int? dot]) => (
  fill: Color(fill),
  border: Color(border),
  text: Color(text),
  dot: dot == null ? null : Color(dot),
);

class PriorityBadge extends StatelessWidget {
  const PriorityBadge(this.priority, {super.key});

  final Priority priority;

  // ponytail: colours copied from the pen file; the 50% and 60% fills are
  // written as alpha hex (0x80, 0x99).
  static final _light = {
    Priority.urgent: _look(false, 0x99FFE4E6, 0xFFFDA4AF, 0xFFBE123C),
    Priority.high: _look(false, 0x80FEF2F2, 0xFFFECACA, 0xFFDC2626),
    Priority.medium: _look(false, 0x80FFFBEB, 0xFFFDE68A, 0xFFB45309),
    Priority.low: _look(false, 0x80EFF6FF, 0xFFBFDBFE, 0xFF2563EB),
  };
  static final _dark = {
    Priority.urgent: _look(true, 0x26F43F5E, 0x66F43F5E, 0xFFFDA4AF),
    Priority.high: _look(true, 0x26EF4444, 0x66EF4444, 0xFFFCA5A5),
    Priority.medium: _look(true, 0x26F59E0B, 0x66F59E0B, 0xFFFCD34D),
    Priority.low: _look(true, 0x263B82F6, 0x663B82F6, 0xFF93C5FD),
  };

  static String label(Priority p) => switch (p) {
    Priority.urgent => 'Urgent',
    Priority.high => 'High',
    Priority.medium => 'Medium',
    Priority.low => 'Low',
  };

  @override
  Widget build(BuildContext context) {
    final l = (AppPalette.of(context).isDark ? _dark : _light)[priority]!;
    return _Badge(
      label: label(priority),
      fill: l.fill,
      border: l.border,
      text: l.text,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final TaskStatus status;

  // To do reads like waiting, as in the app's TASK_DETAIL_STATUS_MAP.
  static final _light = {
    TaskStatus.waiting: _look(
      false,
      0x80F8FAFC,
      0xFFE2E8F0,
      0xFF475569,
      0xFF64748B,
    ),
    TaskStatus.inProgress: _look(
      false,
      0x80EFF6FF,
      0xFFBFDBFE,
      0xFF2563EB,
      0xFF2563EB,
    ),
    TaskStatus.review: _look(
      false,
      0x80FFF7ED,
      0xFFFED7AA,
      0xFFEA580C,
      0xFFF97316,
    ),
    TaskStatus.done: _look(
      false,
      0x80ECFDF5,
      0xFFA7F3D0,
      0xFF059669,
      0xFF10B981,
    ),
  };
  // The pen draws no dark "done"; this is the emerald in the same recipe.
  static final _dark = {
    TaskStatus.waiting: _look(
      true,
      0x2664748B,
      0x6664748B,
      0xFFCBD5E1,
      0xFF94A3B8,
    ),
    TaskStatus.inProgress: _look(
      true,
      0x263B82F6,
      0x663B82F6,
      0xFF93C5FD,
      0xFF60A5FA,
    ),
    TaskStatus.review: _look(
      true,
      0x26F97316,
      0x66F97316,
      0xFFFDBA74,
      0xFFFB923C,
    ),
    TaskStatus.done: _look(
      true,
      0x2610B981,
      0x6610B981,
      0xFF6EE7B7,
      0xFF34D399,
    ),
  };

  static String label(TaskStatus s) => switch (s) {
    TaskStatus.todo => 'To Do',
    TaskStatus.waiting => 'Waiting',
    TaskStatus.inProgress => 'In Progress',
    TaskStatus.review => 'Under Review',
    TaskStatus.done => 'Done',
  };

  @override
  Widget build(BuildContext context) {
    final map = AppPalette.of(context).isDark ? _dark : _light;
    final l = map[status == TaskStatus.todo ? TaskStatus.waiting : status]!;
    return _Badge(
      label: label(status),
      fill: l.fill,
      border: l.border,
      text: l.text,
      dot: l.dot,
    );
  }
}
