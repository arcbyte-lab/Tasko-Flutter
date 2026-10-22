import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../activity_cubit.dart';
import '../activity_text.dart';
import '../models.dart';
import '../tasks_api.dart';
import 'repeating_screen.dart' show Avatar, dayLabel;
import 'task_detail_sheet.dart';

/// Pushes [scope]'s activity log (arcbyte decision 0014). The first page
/// loads before the screen opens, so a refused log (403) shows only its
/// toast. Tapping someone opens their log the same way. Pushed routes sit
/// above the provider, so [api] is handed down.
Future<void> openActivity(
  BuildContext context, {
  required TasksApi api,
  required ActivityScope scope,
  required DateTime today,
}) async {
  final cubit = ActivityCubit(api, scope);
  await cubit.load();
  if (!context.mounted) return cubit.close();
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<ActivityCubit, ActivityState>(
          builder: (context, state) => ActivityView(
            scope: scope,
            state: state,
            today: today,
            onMore: cubit.more,
            onOpenUser: (user) => openActivity(
              context,
              api: api,
              scope: UserLog(user),
              today: today,
            ),
            // A deleted task (404) or one outside the viewer's tabs (403)
            // shows only the error toast. A task's own log is that task.
            onOpenTask: scope is TaskLog
                ? null
                : (id) async {
                    final task = await api.task(id);
                    if (!context.mounted) return;
                    await showTaskDetailSheet(
                      context,
                      api: api,
                      task: task,
                      today: today,
                    );
                    // Changes made there are new rows.
                    await cubit.load();
                  },
          ),
        ),
      ),
    ),
  );
  await cubit.close();
}

/// A log's rows, grouped by day: who, what, and when.
class ActivityView extends StatelessWidget {
  const ActivityView({
    super.key,
    required this.scope,
    required this.state,
    required this.today,
    required this.onMore,
    this.onOpenUser,
    this.onOpenTask,
  });

  final ActivityScope scope;
  final ActivityState state;
  final DateTime today;
  final VoidCallback onMore;

  /// Opens a person's own log. Null hides the link.
  final ValueChanged<User>? onOpenUser;

  /// Opens Task Detail by task id, for rows about a task. Null: rows don't
  /// open.
  final ValueChanged<int>? onOpenTask;

  String get _name => switch (scope) {
    TaskLog(:final task) => task.name,
    TabLog(:final tab) => tab.name,
    UserLog(:final user) => user.name,
  };

  String _day(DateTime d) {
    final days = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(d.year, d.month, d.day)).inDays;
    // Upper case, as every group label is (hifi H9).
    return switch (days) {
      0 => 'TODAY',
      1 => 'YESTERDAY',
      _ => dayLabel(d, today).toUpperCase(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.foreground,
        titleSpacing: 0,
        title: Text(
          '$_name activity',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: switch (items) {
        null => const Center(child: CircularProgressIndicator()),
        // As the repeating view's empty state. A task made before the log
        // existed has no rows, hence the hint.
        [] => const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 40, color: AppColors.controlBorder),
                SizedBox(height: 12),
                Text(
                  'no activity yet',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  'changes from now on show up here',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
        final list => ListView(
          children: [
            for (final (i, e) in list.indexed) ...[
              if (i == 0 || _day(list[i - 1].createdAt) != _day(e.createdAt))
                _DayHeader(_day(e.createdAt)),
              _EntryRow(
                entry: e,
                text: sentence(e, scope, today),
                where: scope is UserLog ? e.tab.name : null,
                onOpenUser: e.actor == null || onOpenUser == null
                    ? null
                    : () => onOpenUser!(e.actor!),
                onOpen: e.subject.type != 'task' || onOpenTask == null
                    ? null
                    : () => onOpenTask!(e.subject.id),
              ),
            ],
            if (state.next != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: TextButton(
                    onPressed: onMore,
                    child: const Text('load more'),
                  ),
                ),
              ),
          ],
        ),
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(label, style: groupLabelStyle()),
  );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.text,
    this.where,
    this.onOpenUser,
    this.onOpen,
  });

  final ActivityEntry entry;
  final String text;
  final VoidCallback? onOpen;

  /// The tab, in a user's log, where rows come from many.
  final String? where;
  final VoidCallback? onOpenUser;

  @override
  Widget build(BuildContext context) {
    final t = entry.createdAt;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final actor =
        entry.actor ??
        User(id: 0, name: entry.actorName.isEmpty ? '?' : entry.actorName);
    final avatar = Avatar(actor, radius: 12);
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onOpenUser == null)
              avatar
            else
              Tooltip(
                message: '${actor.name}’s activity',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onOpenUser,
                  child: avatar,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    where == null || where!.isEmpty ? time : '$time · $where',
                    // Times in mono, as on the repeat screen (hifi H9).
                    style: const TextStyle(
                      fontFamily: fontMono,
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
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
