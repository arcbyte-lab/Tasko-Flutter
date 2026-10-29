import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models.dart';
import '../task_rules.dart';

/// The calendar above the tabs, after the iPhone Calendar app (arcbyte
/// decision 0016, hifi `calendar / month`, `/ day-selected`, `/ fullscreen`).
/// Day numbers with dots for the open tasks due; a selected day collapses
/// it to that week. Expanded, it fills the screen with task titles.
class PulsePanel extends StatelessWidget {
  const PulsePanel({
    super.key,
    required this.month,
    required this.week,
    required this.today,
    required this.dueOn,
    required this.selectedDay,
    required this.showsWeek,
    required this.onDayTap,
    required this.onMonthChange,
    required this.onWeekChange,
    required this.onToday,
    required this.onOpenMonth,
    this.expanded = false,
    this.onToggleExpanded,
  });

  final DateTime month;

  /// The Monday of the week shown while [showsWeek].
  final DateTime week;
  final DateTime today;

  /// Open tasks by due day; any day before [today] is overdue.
  final Map<DateTime, List<Task>> dueOn;
  final DateTime? selectedDay;
  final bool showsWeek;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<int> onMonthChange;
  final ValueChanged<int> onWeekChange;
  final VoidCallback onToday;
  final VoidCallback onOpenMonth;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  /// The weeks on show: just [week] in the strip, else [month]'s weeks with
  /// null for the days outside it.
  List<List<DateTime?>> _weeks(bool strip) {
    if (strip) {
      return [
        [
          for (var i = 0; i < 7; i++)
            DateTime(week.year, week.month, week.day + i),
        ],
      ];
    }
    final leading = DateTime(month.year, month.month).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((leading + days) / 7).ceil();
    return [
      for (var r = 0; r < rows; r++)
        [
          for (var c = 0; c < 7; c++)
            switch (r * 7 + c - leading + 1) {
              final day when day >= 1 && day <= days => DateTime(
                month.year,
                month.month,
                day,
              ),
              _ => null,
            },
        ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final strip = showsWeek && !expanded;
    Widget cell(DateTime? d) => Expanded(
      child: d == null
          ? const SizedBox()
          : _Day(
              date: d,
              tasks: dueOn[d] ?? const [],
              overdue: d.isBefore(today),
              isToday: isSameDay(d, today),
              selected: selectedDay != null && isSameDay(d, selectedDay!),
              big: expanded,
              onTap: () => onDayTap(d),
            ),
    );
    Widget row(List<DateTime?> w) => Container(
      height: expanded ? null : 40,
      padding: EdgeInsets.symmetric(horizontal: expanded ? 4 : 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final d in w) cell(d)],
      ),
    );

    final weeks = _weeks(strip);
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() <= 200) return;
        (strip ? onWeekChange : onMonthChange)(v < 0 ? 1 : -1);
      },
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.muted,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              month: month,
              strip: strip,
              expanded: expanded,
              onToday: onToday,
              onOpenMonth: onOpenMonth,
              onToggleExpanded: onToggleExpanded,
            ),
            _Weekdays(padding: expanded ? 4 : 8),
            if (expanded)
              for (final w in weeks) Expanded(child: row(w))
            else
              // Scrolls when the screen is short (landscape) instead of
              // overflowing; HomeView caps the panel's height.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(children: [for (final w in weeks) row(w)]),
                ),
              ),
            if (strip) _Grabber(onOpen: onOpenMonth),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.month,
    required this.strip,
    required this.expanded,
    required this.onToday,
    required this.onOpenMonth,
    required this.onToggleExpanded,
  });

  final DateTime month;
  final bool strip;
  final bool expanded;
  final VoidCallback onToday;
  final VoidCallback onOpenMonth;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          monthNames[month.month - 1],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${month.year}',
          style: const TextStyle(
            fontSize: 22,
            color: AppColors.mutedForeground,
          ),
        ),
        if (strip)
          const Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: AppColors.mutedForeground,
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          // Shrinks rather than overflow with large text or a long month.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: strip
                  ? Semantics(
                      button: true,
                      label: 'Show month',
                      excludeSemantics: true,
                      child: GestureDetector(onTap: onOpenMonth, child: title),
                    )
                  : title,
            ),
          ),
          TextButton(
            onPressed: onToday,
            child: const Text(
              'Today',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
          if (onToggleExpanded != null)
            IconButton(
              onPressed: onToggleExpanded,
              tooltip: expanded ? 'Collapse calendar' : 'Expand calendar',
              icon: Icon(
                expanded ? Icons.close_fullscreen : Icons.open_in_full,
                size: 20,
                color: AppColors.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }
}

class _Weekdays extends StatelessWidget {
  const _Weekdays({required this.padding});

  final double padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(padding, 4, padding, 6),
    child: Row(
      children: [
        for (final (i, d) in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'].indexed)
          Expanded(
            child: Text(
              d,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: i > 4
                    ? AppColors.placeholder
                    : AppColors.mutedForeground,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Under the week strip: tap or drag down to open the month again.
class _Grabber extends StatelessWidget {
  const _Grabber({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Show month',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onOpen,
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 0) onOpen();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.controlBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Day extends StatelessWidget {
  const _Day({
    required this.date,
    required this.tasks,
    required this.overdue,
    required this.isToday,
    required this.selected,
    required this.big,
    required this.onTap,
  });

  final DateTime date;

  /// Open tasks due this day, in order.
  final List<Task> tasks;
  final bool overdue;
  final bool isToday;
  final bool selected;

  /// The full-screen cell, with task titles.
  final bool big;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weekend = date.weekday >= DateTime.saturday;
    // Selected wins over today.
    final fill = selected
        ? AppColors.foreground
        : isToday
        ? AppColors.primary
        : null;
    final circle = big ? 24.0 : 28.0;
    final number = Container(
      width: circle,
      height: circle,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Text(
        '${date.day}',
        style: TextStyle(
          fontSize: big ? 13 : 15,
          fontWeight: fill != null
              ? FontWeight.w600
              : big
              ? FontWeight.w500
              : FontWeight.w400,
          color: fill != null
              ? Colors.white
              : weekend
              ? AppColors.placeholder
              : AppColors.foreground,
        ),
      ),
    );

    final Widget body;
    if (big) {
      // Up to 3 titles, or 2 and "+N more" (0016). A short cell clips the
      // rest rather than overflowing.
      final shown = tasks.length > 3 ? tasks.take(2) : tasks;
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              number,
              for (final t in shown) ...[
                const SizedBox(height: 3),
                _Pill(title: t.name, overdue: overdue),
              ],
              if (tasks.length > 3) ...[
                const SizedBox(height: 3),
                Text(
                  '+${tasks.length - 2} more',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      final dots = dotCount(tasks.length);
      body = Column(
        children: [
          const SizedBox(height: 3),
          number,
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < dots; i++)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: overdue ? AppColors.destructive : AppColors.primary,
                  ),
                ),
            ],
          ),
        ],
      );
    }

    final open = tasks.isEmpty ? '' : ', ${tasks.length} open';
    return Semantics(
      button: true,
      selected: selected,
      label: 'Day ${date.day}$open',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: body,
      ),
    );
  }
}

/// A task title in a full-screen day: one line, cut off with no ellipsis,
/// as in the drawing.
class _Pill extends StatelessWidget {
  const _Pill({required this.title, required this.overdue});

  final String title;
  final bool overdue;

  @override
  Widget build(BuildContext context) => Container(
    height: 16,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: overdue
          ? AppColors.destructive.withValues(alpha: 0.12)
          : AppColors.accent,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      title,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: overdue ? AppColors.destructive : AppColors.accentForeground,
      ),
    ),
  );
}
