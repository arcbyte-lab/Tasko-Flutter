import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models.dart';
import '../task_rules.dart';

/// The calendar above the tabs, after the iPhone Calendar app (arcbyte
/// decision 0016, hifi `calendar / month`, `/ day-selected`, `/ fullscreen`).
/// Day numbers with dots for the open tasks due. It folds between the month
/// and a week strip by [fold]; [CalendarFold] drives that from a drag on the
/// tab bar or the handle. Expanded, it fills the screen with task titles.
class PulsePanel extends StatelessWidget {
  const PulsePanel({
    super.key,
    required this.month,
    required this.week,
    required this.today,
    required this.dueOn,
    required this.taskDays,
    required this.selectedDay,
    required this.showsWeek,
    required this.onDayTap,
    required this.onMonthChange,
    required this.onWeekChange,
    required this.onToday,
    required this.fold,
    required this.handle,
    this.expanded = false,
    this.onToggleExpanded,
  });

  final DateTime month;

  /// The Monday of the week shown while [showsWeek].
  final DateTime week;
  final DateTime today;

  /// Open tasks by due day; any day before [today] is overdue.
  final Map<DateTime, List<Task>> dueOn;

  /// Every task by due day, whatever its status, for the rings.
  final Map<DateTime, List<Task>> taskDays;
  final DateTime? selectedDay;
  final bool showsWeek;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<int> onMonthChange;
  final ValueChanged<int> onWeekChange;
  final VoidCallback onToday;

  /// 1 shows the month, 0 the week strip; in between, the month unfolds
  /// from the week's row.
  final Animation<double> fold;

  /// Makes its child drag the fold (from [CalendarFold]).
  final Widget Function(Widget child) handle;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  /// A week row, 44 tall (hifi H12).
  static const _rowHeight = 44.0;

  /// The month always has room for 6 weeks, so it does not change height
  /// from one month to the next.
  static const _monthRows = 6;

  /// The weeks of the page [step] pages from the current one: one week in
  /// the strip, else a month's weeks with null for the days outside it.
  List<List<DateTime?>> _weeks(bool strip, int step) {
    if (strip) {
      return [
        [
          for (var i = 0; i < 7; i++)
            DateTime(week.year, week.month, week.day + 7 * step + i),
        ],
      ];
    }
    final month = DateTime(this.month.year, this.month.month + step);
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

  /// Half-way between month and week: [month]'s grid, its height between
  /// one row and all of them, shifted so the folding week's row stays put.
  Widget _folding(double t, Widget monthGrid) {
    const rowHeight = _rowHeight;
    final first = mondayOf(DateTime(month.year, month.month));
    final rows = _monthRows;
    final anchor = showsWeek ? week : foldWeek(month, selectedDay, today);
    final row = (anchor.difference(first).inHours / (24 * 7)).round().clamp(
      0,
      _weeks(false, 0).length - 1,
    );
    final top = row * rowHeight;
    return SizedBox(
      height: rowHeight + (rows - 1) * rowHeight * t,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -top * (1 - t),
              left: 0,
              right: 0,
              child: IgnorePointer(child: monthGrid),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: fold,
    builder: (context, _) => _build(expanded ? 1 : fold.value),
  );

  Widget _build(double t) {
    final strip = t == 0;
    Widget cell(DateTime? d) => Expanded(
      child: d == null
          ? const SizedBox()
          : _Day(
              date: d,
              tasks: dueOn[d] ?? const [],
              all: taskDays[d] ?? const [],
              marks: dayMarks(taskDays[d] ?? const [], d, today),
              today: today,
              overdue: d.isBefore(today),
              isToday: isSameDay(d, today),
              selected: selectedDay != null && isSameDay(d, selectedDay!),
              big: expanded,
              onTap: () => onDayTap(d),
            ),
    );
    Widget row(List<DateTime?> w) => Container(
      height: expanded ? null : _rowHeight,
      padding: EdgeInsets.symmetric(horizontal: expanded ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final d in w) cell(d)],
      ),
    );

    Widget grid(int step) => Column(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final w in _weeks(strip, step))
          expanded ? Expanded(child: row(w)) : row(w),
        // A 4 or 5 week month keeps the height of 6.
        if (!strip && !expanded)
          for (var i = _weeks(strip, step).length; i < _monthRows; i++)
            const SizedBox(height: _rowHeight),
      ],
    );
    final pager = _Pager(
      page: (strip: strip, start: strip ? week : month),
      fill: expanded,
      grid: grid,
      onChange: strip ? onWeekChange : onMonthChange,
    );

    final panel = Container(
      color: AppColors.muted,
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (expanded) const _TopGrabber(),
          _Header(
            month: month,
            expanded: expanded,
            onToday: onToday,
            onToggleExpanded: onToggleExpanded,
          ),
          _Weekdays(padding: expanded ? 4 : 8),
          if (expanded)
            Expanded(child: pager)
          else
            // Scrolls when the screen is short (landscape) instead of
            // overflowing; HomeView caps the panel's height.
            Flexible(
              child: SingleChildScrollView(
                child: t == 0 || t == 1 ? pager : _folding(t, grid(0)),
              ),
            ),
          if (!expanded) handle(const _Handle()),
        ],
      ),
    );
    // Full screen: 16px rounded top corners over the black bar (hifi H12).
    return expanded
        ? ColoredBox(
            color: Colors.black,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: panel,
            ),
          )
        : panel;
  }
}

/// The 36×4 grabber at the top of the full-screen panel. It only decorates:
/// the corner icon closes the view.
class _TopGrabber extends StatelessWidget {
  const _TopGrabber();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
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
  );
}

typedef _Page = ({bool strip, DateTime start});

/// The month or week grid, following the finger sideways with the next or
/// previous one beside it. Let go past a third of the width, or flick, and
/// it moves on; otherwise it springs back. A change from elsewhere ("Today")
/// slides in the same way. Switching between month and week strip is
/// instant.
class _Pager extends StatefulWidget {
  const _Pager({
    required this.page,
    required this.fill,
    required this.grid,
    required this.onChange,
  });

  final _Page page;

  /// Fill the height (full screen) rather than size to the grid.
  final bool fill;

  /// The grid [step] pages away: -1 before, 0 this one, 1 after.
  final Widget Function(int step) grid;
  final ValueChanged<int> onChange;

  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 250);

  /// How far the grid is pulled sideways, in pixels.
  late final _dx = AnimationController.unbounded(vsync: this);
  var _width = 0.0;

  /// The page change about to arrive came from our own swipe, so it must
  /// not slide in again.
  var _moved = false;

  @override
  void dispose() {
    _dx.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Pager old) {
    super.didUpdateWidget(old);
    final (a, b) = (old.page, widget.page);
    if (a == b) return;
    if (_moved || a.strip != b.strip || _width == 0) {
      _moved = false;
      _dx.value = 0;
      return;
    }
    // Start one width off to the side it comes from, then slide in.
    _dx.value = b.start.isAfter(a.start) ? _width : -_width;
    _dx.animateTo(0, duration: _duration, curve: Curves.easeOutCubic);
  }

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final dx = _dx.value;
    final step = dx < -_width / 3 || v < -300
        ? 1
        : dx > _width / 3 || v > 300
        ? -1
        : 0;
    if (step == 0) {
      _dx.animateTo(0, duration: _duration, curve: Curves.easeOutCubic);
      return;
    }
    _dx
        .animateTo(
          -step * _width,
          duration: _duration,
          curve: Curves.easeOutCubic,
        )
        .whenCompleteOrCancel(() {
          if (!mounted) return;
          _moved = true;
          widget.onChange(step);
        });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      _width = box.maxWidth;
      return GestureDetector(
        onHorizontalDragStart: (_) => _dx.stop(),
        onHorizontalDragUpdate: (d) => _dx.value += d.delta.dx,
        onHorizontalDragEnd: _end,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _dx,
            builder: (context, current) {
              final dx = _dx.value;
              // A neighbour only shows, and only builds, while pulled.
              Widget side(int step) => Positioned(
                left: dx + step * _width,
                top: 0,
                bottom: widget.fill ? 0 : null,
                width: _width,
                child: IgnorePointer(
                  child: ExcludeSemantics(child: widget.grid(step)),
                ),
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Transform.translate(offset: Offset(dx, 0), child: current),
                  if (dx > 0) side(-1),
                  if (dx < 0) side(1),
                ],
              );
            },
            child: widget.grid(0),
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.month,
    required this.expanded,
    required this.onToday,
    required this.onToggleExpanded,
  });

  final DateTime month;
  final bool expanded;
  final VoidCallback onToday;
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
              child: title,
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

/// The bar under the calendar: a hint that it folds by dragging, here or on
/// the tab bar. It has no tap.
class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Drag to fold the calendar',
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
  );
}

/// Owns the fold between month (1) and week strip (0) and lets a vertical
/// drag pull it with the finger: down opens the month, up folds it to a
/// week. Let go past half way, or flick, and it finishes; otherwise it goes
/// back. A change from elsewhere (a day tap, "Today", clearing the day)
/// animates the same fold.
class CalendarFold extends StatefulWidget {
  const CalendarFold({
    super.key,
    required this.showsWeek,
    required this.onOpen,
    required this.onFold,
    required this.builder,
  });

  final bool showsWeek;
  final VoidCallback onOpen;
  final VoidCallback onFold;

  /// [handle] wraps whatever should drag the fold: the tab bar, the bar.
  final Widget Function(
    BuildContext context,
    Animation<double> fold,
    Widget Function(Widget child) handle,
  )
  builder;

  @override
  State<CalendarFold> createState() => _CalendarFoldState();
}

class _CalendarFoldState extends State<CalendarFold>
    with SingleTickerProviderStateMixin {
  // ponytail: a fixed pull distance, about four 40px rows; measure the
  // month's real height if 4- and 6-row months feel off.
  static const _pull = 160.0;

  late final _fold = AnimationController(
    vsync: this,
    value: widget.showsWeek ? 0 : 1,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void didUpdateWidget(CalendarFold old) {
    super.didUpdateWidget(old);
    if (old.showsWeek != widget.showsWeek) _settle(open: !widget.showsWeek);
  }

  @override
  void dispose() {
    _fold.dispose();
    super.dispose();
  }

  void _settle({required bool open}) =>
      _fold.animateTo(open ? 1 : 0, curve: Curves.easeOutCubic);

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final open = v.abs() > 300 ? v > 0 : _fold.value > 0.5;
    _settle(open: open);
    if (open == widget.showsWeek) (open ? widget.onOpen : widget.onFold)();
  }

  Widget _handle(Widget child) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onVerticalDragStart: (_) => _fold.stop(),
    onVerticalDragUpdate: (d) => _fold.value += d.delta.dy / _pull,
    onVerticalDragEnd: _end,
    child: child,
  );

  @override
  Widget build(BuildContext context) => widget.builder(context, _fold, _handle);
}

class _Day extends StatelessWidget {
  const _Day({
    required this.date,
    required this.tasks,
    required this.all,
    required this.marks,
    required this.today,
    required this.overdue,
    required this.isToday,
    required this.selected,
    required this.big,
    required this.onTap,
  });

  final DateTime date;

  /// Open tasks due this day, in order.
  final List<Task> tasks;

  /// Every task due this day, whatever its status: the full-screen titles.
  final List<Task> all;
  final DateTime today;

  /// The arcs of the ring: one per kind of task due this day.
  final Set<DayMark> marks;
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
        ? (big ? const Color(0xFF2563EB) : Colors.black)
        : null;
    final circle = big ? 30.0 : 36.0;
    final number = Container(
      width: circle,
      height: circle,
      alignment: Alignment.center,
      // Every day is a grey disc in the month and the week (hifi H12).
      decoration: BoxDecoration(
        color: fill ?? AppColors.secondary,
        shape: BoxShape.circle,
      ),
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
      final shown = all.length > 3 ? all.take(2) : all;
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              CustomPaint(
                foregroundPainter: DayRingPainter(marks),
                child: number,
              ),
              for (final t in shown) ...[
                const SizedBox(height: 3),
                _Pill(title: t.name, mark: markOf(t, date, today)),
              ],
              if (all.length > 3) ...[
                const SizedBox(height: 3),
                Text(
                  '+${all.length - 2} more',
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
      body = Center(
        child: CustomPaint(
          foregroundPainter: DayRingPainter(marks),
          child: number,
        ),
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
  const _Pill({required this.title, required this.mark});

  final String title;
  final DayMark mark;

  /// Background and text: red overdue, blue open, amber in review, green done.
  static const _colors = {
    DayMark.overdue: (Color(0x1FEF4444), Color(0xFFDC2626)),
    DayMark.open: (AppColors.accent, AppColors.accentForeground),
    DayMark.review: (Color(0xFFFEF3C7), Color(0xFF92400E)),
    DayMark.done: (Color(0xFFDCFCE7), Color(0xFF166534)),
  };

  @override
  Widget build(BuildContext context) => Container(
    height: 16,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: _colors[mark]!.$1,
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
        color: _colors[mark]!.$2,
      ),
    ),
  );
}

/// The ring round a day: one arc per kind of task, split evenly and drawn
/// clockwise from the top in [DayMark] order (hifi H12). No tasks, no ring.
class DayRingPainter extends CustomPainter {
  DayRingPainter(this.marks);

  final Set<DayMark> marks;

  static const _colors = {
    DayMark.overdue: Color(0xFFEF4444),
    DayMark.open: Color(0xFF2563EB),
    DayMark.review: Color(0xFFF97316),
    DayMark.done: Color(0xFF16A34A),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (marks.isEmpty) return;
    const width = 2.0;
    const pi = 3.141592653589793;
    final rect = (Offset.zero & size).deflate(width / 2);
    final kinds = [
      for (final m in DayMark.values)
        if (marks.contains(m)) m,
    ];
    final sweep = 2 * pi / kinds.length;
    for (var i = 0; i < kinds.length; i++) {
      canvas.drawArc(
        rect,
        -pi / 2 + i * sweep,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = _colors[kinds[i]]!,
      );
    }
  }

  @override
  bool shouldRepaint(DayRingPainter old) => !setEquals(old.marks, marks);
}
