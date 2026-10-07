import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../task_rules.dart';

/// The monthly due-date heatmap above the tabs (arcbyte decision 0003).
/// Swipe or use the chevrons to change month; tap a day to filter the list.
/// Expanded, it fills the screen with big cells that show the day and its
/// open count (arcbyte lofi T3, hifi H2).
class PulsePanel extends StatelessWidget {
  const PulsePanel({
    super.key,
    required this.month,
    required this.today,
    required this.counts,
    required this.overdueDays,
    required this.selectedDay,
    required this.onDayTap,
    required this.onMonthChange,
    this.expanded = false,
    this.onToggleExpanded,
  });

  final DateTime month;
  final DateTime today;
  final Map<int, int> counts;
  final Set<int> overdueDays;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<int> onMonthChange;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  static Color cellColor(int count) => switch (count) {
    0 => AppColors.heatmapEmpty,
    1 => AppColors.accent,
    2 || 3 => AppColors.primary,
    _ => AppColors.heatmapBusiest,
  };

  @override
  Widget build(BuildContext context) {
    final title = month.year == today.year
        ? monthNames[month.month - 1]
        : '${monthNames[month.month - 1]} ${month.year}';
    final leading = DateTime(month.year, month.month).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((leading + days) / 7).ceil();

    Widget cell(int index) {
      final day = index - leading + 1;
      if (day < 1 || day > days) {
        return expanded
            ? const Expanded(child: SizedBox())
            : const SizedBox(width: 32, height: 36);
      }
      final date = DateTime(month.year, month.month, day);
      final c = _DayCell(
        day: day,
        count: counts[day] ?? 0,
        isToday: isSameDay(date, today),
        selected: selectedDay != null && isSameDay(date, selectedDay!),
        overdue: overdueDays.contains(day),
        big: expanded,
        onTap: () => onDayTap(date),
      );
      return expanded
          ? Expanded(
              child: Padding(padding: const EdgeInsets.all(4), child: c),
            )
          : c;
    }

    Widget weekday(String d) {
      final label = Center(
        child: Text(
          d,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.mutedForeground,
          ),
        ),
      );
      return expanded
          ? Expanded(child: SizedBox(height: 28, child: label))
          : SizedBox(width: 32, height: 20, child: label);
    }

    final size = expanded ? MainAxisSize.max : MainAxisSize.min;
    final grid = Column(
      children: [
        Row(
          mainAxisSize: size,
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              weekday(d),
          ],
        ),
        for (var r = 0; r < rows; r++)
          Row(
            mainAxisSize: size,
            children: [for (var c = 0; c < 7; c++) cell(r * 7 + c)],
          ),
      ],
    );

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 200) onMonthChange(v < 0 ? 1 : -1);
      },
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.muted,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('MONTHLY', style: groupLabelStyle()),
            ),
            Row(
              children: [
                _Chevron(
                  icon: Icons.chevron_left,
                  label: 'Previous month',
                  onTap: () => onMonthChange(-1),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                _Chevron(
                  icon: Icons.chevron_right,
                  label: 'Next month',
                  onTap: () => onMonthChange(1),
                ),
                const Spacer(),
                if (onToggleExpanded != null)
                  _Chevron(
                    icon: expanded
                        ? Icons.close_fullscreen
                        : Icons.open_in_full,
                    label: expanded ? 'Collapse calendar' : 'Expand calendar',
                    onTap: onToggleExpanded!,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (expanded) grid else Center(child: grid),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.isToday,
    required this.selected,
    required this.overdue,
    required this.big,
    required this.onTap,
  });

  final int day;
  final int count;
  final bool isToday;
  final bool selected;
  final bool overdue;

  /// The full-screen cell: day number and open count inside it.
  final bool big;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Selected: a 2px primary ring with a 2px white gap. Today: a dark outline.
    final ring = selected
        ? [
            // Painted in order, so the white gap goes on top of the ring.
            const BoxShadow(color: AppColors.primary, spreadRadius: 4),
            const BoxShadow(color: Colors.white, spreadRadius: 2),
          ]
        : null;
    final box = BoxDecoration(
      color: PulsePanel.cellColor(count),
      borderRadius: BorderRadius.circular(4),
      border: isToday && !selected
          ? Border.all(color: AppColors.foreground, width: 1.5)
          : null,
      boxShadow: ring,
    );
    final dot = Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: overdue ? AppColors.destructive : Colors.transparent,
      ),
    );

    // Primary and busiest fills (2 or more) take white text.
    final dark = count >= 2;
    final body = big
        ? AspectRatio(
            aspectRatio: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: box,
                    padding: const EdgeInsets.all(5),
                    // Pinned to corners, not stacked, so a small cell can't
                    // overflow.
                    child: Stack(
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: dark ? Colors.white : AppColors.foreground,
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 12,
                                color: dark
                                    ? Colors.white
                                    : AppColors.mutedForeground,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  left: 0,
                  right: 0,
                  child: Center(child: dot),
                ),
              ],
            ),
          )
        : SizedBox(
            width: 32,
            height: 36,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 24, height: 24, decoration: box),
                const SizedBox(height: 2),
                dot,
              ],
            ),
          );

    return Semantics(
      button: true,
      selected: selected,
      label: 'Day $day',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: body,
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: label,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, size: 20, color: AppColors.mutedForeground),
  );
}
