import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../models.dart';
import '../repeating_cubit.dart';
import '../task_rules.dart';
import '../tasks_api.dart';

/// Pushes [tab]'s repeating view (arcbyte decision 0012, hifi H8).
/// [onNew] creates a repeating task; [onOpen] shows one series. The list
/// reloads after either. Completes when the user goes back.
Future<void> openRepeating(
  BuildContext context, {
  required TaskTab tab,
  required List<Member> members,
  required DateTime today,
  required Future<void> Function(BuildContext context) onNew,
  Future<void> Function(BuildContext context, Task task)? onOpen,
}) {
  final api = context.read<TasksApi>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider(
        create: (_) => RepeatingCubit(api, tab)..load(),
        child: Builder(
          builder: (context) {
            final cubit = context.read<RepeatingCubit>();
            return BlocBuilder<RepeatingCubit, List<RepeatingSeries>?>(
              builder: (context, series) => RepeatingView(
                tab: tab,
                series: series,
                members: members,
                today: today,
                onNew: () async {
                  await onNew(context);
                  await cubit.load();
                },
                onOpen: onOpen == null
                    ? null
                    : (task) async {
                        await onOpen(context, task);
                        await cubit.load();
                      },
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// The live repeating tasks, soonest first: name, rule and next due date,
/// the assignee, and a dot per recent occurrence, oldest on the left.
class RepeatingView extends StatelessWidget {
  const RepeatingView({
    super.key,
    required this.tab,
    required this.series,
    required this.members,
    required this.today,
    required this.onNew,
    this.onOpen,
  });

  final TaskTab tab;

  /// Null while loading.
  final List<RepeatingSeries>? series;
  final List<Member> members;
  final DateTime today;
  final VoidCallback onNew;
  final ValueChanged<Task>? onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.foreground,
      titleSpacing: 0,
      title: Text(
        '${tab.name} repeating',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      actions: [
        TextButton(
          onPressed: onNew,
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15),
          ),
          child: const Text('+ new'),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: switch (series) {
      null => const Center(child: CircularProgressIndicator()),
      [] => const _Empty(),
      final list => ListView(
        children: [
          for (final s in list)
            _SeriesRow(
              series: s,
              assignee: members
                  .where((m) => m.user.id == s.task.assigneeId)
                  .firstOrNull
                  ?.user,
              today: today,
              onTap: onOpen == null ? null : () => onOpen!(s.task),
            ),
        ],
      ),
    },
  );
}

/// "Mon, Oct 12".
String dayLabel(DateTime d, DateTime now) =>
    '${weekdayShort[d.weekday - 1]}, ${shortDate(d, now)}';

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({
    required this.series,
    required this.assignee,
    required this.today,
    this.onTap,
  });

  final RepeatingSeries series;
  final User? assignee;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = series.task;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    '${repeatSummary(t.repeat!, today)} · '
                    'next ${dayLabel(t.dueDate!, today)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  if (series.recent.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Oldest on the left, so the row reads as a timeline.
                        for (final onTime in series.recent.reversed)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Semantics(
                              label: onTime ? 'on time' : 'late',
                              child: CircleAvatar(
                                radius: 4,
                                backgroundColor: onTime
                                    ? AppColors.primary
                                    : AppColors.destructive,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (assignee != null) Avatar(assignee!, radius: 12),
          ],
        ),
      ),
    );
  }
}

/// A user's initial in a circle.
class Avatar extends StatelessWidget {
  const Avatar(this.user, {super.key, this.radius = 10});

  final User user;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.accent,
    child: Text(
      user.name[0].toUpperCase(),
      style: TextStyle(
        fontSize: radius - 1,
        fontWeight: FontWeight.w600,
        color: AppColors.accentForeground,
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.only(bottom: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 40, color: AppColors.controlBorder),
          SizedBox(height: 12),
          Text(
            'no repeating tasks yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            'tap + new to set one up',
            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
        ],
      ),
    ),
  );
}
