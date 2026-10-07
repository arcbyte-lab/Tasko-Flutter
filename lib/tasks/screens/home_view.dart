import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../home_cubit.dart';
import '../models.dart';
import '../task_rules.dart';
import '../widgets/pulse_panel.dart';
import '../widgets/tab_strip.dart';
import '../widgets/task_row.dart';

/// The home screen, drawn from plain [state]. Wiring lives in HomePanel.
class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.state,
    required this.onSelectTab,
    required this.onDayTap,
    required this.onClearDay,
    required this.onMonthChange,
    required this.onToggleCompleted,
    required this.onTick,
    required this.onOpen,
    required this.onNotifications,
    required this.onCreate,
    required this.onStartSearch,
    required this.onSearch,
    required this.onStopSearch,
    required this.onViewOptions,
  });

  final HomeState state;
  final ValueChanged<TaskTab> onSelectTab;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onClearDay;
  final ValueChanged<int> onMonthChange;
  final VoidCallback onToggleCompleted;
  final ValueChanged<Task> onTick;
  final VoidCallback onCreate;
  final ValueChanged<Task> onOpen;
  final VoidCallback onNotifications;
  final VoidCallback onStartSearch;
  final ValueChanged<String> onSearch;
  final VoidCallback onStopSearch;
  final VoidCallback onViewOptions;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final listed = state.listed;
    final completed = state.completed;
    final day = state.selectedDay;

    Widget row(Task t) => TaskRow(
      task: t,
      now: state.today,
      onTick: () => onTick(t),
      onTap: () => onOpen(t),
    );

    final items = <Widget>[
      if (state.searching)
        _SearchField(
          key: const ValueKey('search'),
          onChanged: onSearch,
          onClose: onStopSearch,
        )
      else
        _Toolbar(
          count: listed.length,
          customised: !state.view.isDefault,
          onSearch: onStartSearch,
          onViewOptions: onViewOptions,
        ),
      if (day != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _DayChip(
              label: shortDate(day, state.today),
              onClear: onClearDay,
            ),
          ),
        ),
      if (listed.isEmpty && completed.isEmpty)
        const _EmptyState()
      else
        for (final s in state.sections) ...[
          if (s.label != null) _GroupHeader(s.label!, alert: s.alert),
          ...s.tasks.map(row),
        ],
      if (completed.isNotEmpty) ...[
        _CompletedRow(
          count: completed.length,
          open: state.showCompleted,
          onTap: onToggleCompleted,
        ),
        if (state.showCompleted) ...completed.map(row),
      ],
      const SizedBox(height: 88), // room to scroll past the FAB
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              name: state.user!.name,
              unread: state.unread > 0,
              onNotifications: onNotifications,
            ),
            PulsePanel(
              month: state.month,
              today: state.today,
              counts: state.dueCountsThisMonth,
              overdueDays: state.overdueDays,
              selectedDay: day,
              onDayTap: onDayTap,
              onMonthChange: onMonthChange,
            ),
            TabStrip(
              tabs: state.tabs,
              active: state.activeTab,
              onSelect: onSelectTab,
            ),
            Expanded(child: ListView(children: items)),
          ],
        ),
      ),
      // Hidden while searching, as in the mockup.
      floatingActionButton: state.searching
          ? null
          : FloatingActionButton(
              onPressed: onCreate,
              tooltip: 'Create task',
              shape: const CircleBorder(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 1,
              child: const Icon(Icons.add),
            ),
    );
  }
}

// ponytail: the slider icon (meaning still open) and the calendar's maximize
// icon are left out until their screens are built.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.name,
    required this.unread,
    required this.onNotifications,
  });

  final String name;
  final bool unread;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.only(left: 16, right: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'welcome, $name',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
        ),
        IconButton(
          onPressed: onNotifications,
          tooltip: unread ? 'Notifications, unread' : 'Notifications',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none,
                size: 20,
                color: AppColors.mutedForeground,
              ),
              if (unread)
                // 6px red dot with a 1.5px white ring (hifi H1).
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.destructive,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primary,
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.count,
    required this.customised,
    required this.onSearch,
    required this.onViewOptions,
  });

  final int count;

  /// Group, sort or a filter differs from the default.
  final bool customised;
  final VoidCallback onSearch;
  final VoidCallback onViewOptions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$count open',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        IconButton(
          onPressed: onSearch,
          tooltip: 'Search',
          icon: const Icon(Icons.search, color: AppColors.mutedForeground),
        ),
        IconButton(
          onPressed: onViewOptions,
          tooltip: 'View options',
          icon: Icon(
            Icons.tune,
            color: customised ? AppColors.primary : AppColors.mutedForeground,
          ),
        ),
      ],
    ),
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    super.key,
    required this.onChanged,
    required this.onClose,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: c, width: w),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'search tasks',
          hintStyle: const TextStyle(color: AppColors.placeholder),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.mutedForeground,
          ),
          suffixIcon: IconButton(
            onPressed: onClose,
            tooltip: 'Close search',
            icon: const Icon(Icons.close, color: AppColors.mutedForeground),
          ),
          enabledBorder: border(AppColors.border, 1),
          focusedBorder: border(AppColors.primary, 2),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primary,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      onTap: onClear,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.close,
              size: 16,
              color: Colors.white,
              semanticLabel: 'Clear day',
            ),
          ],
        ),
      ),
    ),
  );
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label, {this.alert = false});

  final String label;

  /// OVERDUE is red.
  final bool alert;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      label,
      style: groupLabelStyle(
        color: alert ? AppColors.destructive : AppColors.mutedForeground,
      ),
    ),
  );
}

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Text(
            'completed ($count)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            open ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: AppColors.mutedForeground,
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 64),
    child: Column(
      children: [
        Icon(Icons.inbox_outlined, size: 40, color: AppColors.controlBorder),
        SizedBox(height: 12),
        Text(
          'no tasks here',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.foreground,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'tap + to add one',
          style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
        ),
      ],
    ),
  );
}
