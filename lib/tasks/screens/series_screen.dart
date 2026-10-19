import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../core/toast.dart';
import '../http_tasks_api.dart' show ApiException;
import '../models.dart';
import '../series_cubit.dart';
import '../task_rules.dart';
import '../tasks_api.dart';
import 'repeat_screen.dart';
import 'repeating_screen.dart' show Avatar, dayLabel;
import 'task_detail_sheet.dart';

/// Pushes the history of [task]'s series (arcbyte decision 0012, hifi H8).
/// Completes when the user goes back, or after the repeat is stopped or
/// deleted.
Future<void> openSeries(
  BuildContext context, {
  required TasksApi api,
  required Task task,
  required List<Member> members,
  required DateTime today,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => BlocProvider(
      create: (_) => SeriesCubit(api, task.seriesId!)..load(),
      child: _SeriesPanel(api: api, task: task, members: members, today: today),
    ),
  ),
);

/// The series menu: edit repeat, stop repeating, delete.
enum SeriesAction { edit, stop, delete }

class _SeriesPanel extends StatelessWidget {
  const _SeriesPanel({
    required this.api,
    required this.task,
    required this.members,
    required this.today,
  });

  final TasksApi api;
  final Task task;
  final List<Member> members;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SeriesCubit>();
    return BlocBuilder<SeriesCubit, List<Occurrence>?>(
      builder: (context, history) => SeriesView(
        // The list's copy until the history loads, then the live one.
        task: cubit.open ?? task,
        history: history,
        members: members,
        today: today,
        onOpen: (t) async {
          await showTaskDetailSheet(context, api: api, task: t, today: today);
          await cubit.load();
        },
        onAction: (action) async {
          switch (action) {
            case SeriesAction.edit:
              final open = cubit.open ?? task;
              final v = await openRepeatScreen(
                context,
                initial: open.repeat,
                due: open.dueDate!,
              );
              if (v == null) return;
              await cubit.setRepeat(v.$1);
              if (v.$1 == null && context.mounted) Navigator.pop(context);
            case SeriesAction.stop:
              await cubit.setRepeat(null);
              if (context.mounted) Navigator.pop(context);
            case SeriesAction.delete:
              if (!await _confirmDelete(context, cubit.open ?? task, today)) {
                return;
              }
              try {
                await cubit.delete();
                if (context.mounted) Navigator.pop(context);
              } on ApiException catch (e) {
                if (context.mounted) showToast(context, e.message);
              }
          }
        },
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, Task open, DateTime today) =>
    showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'delete this repeating task?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'the open task, due ${dayLabel(open.dueDate!, today)}, '
                'is deleted. finished tasks stay.',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.destructive,
                      ),
                      child: const Text('delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((v) => v ?? false);

/// The rule, then every occurrence, newest first: its due date, assignee,
/// and status while open or how it went once done.
class SeriesView extends StatelessWidget {
  const SeriesView({
    super.key,
    required this.task,
    required this.history,
    required this.members,
    required this.today,
    required this.onOpen,
    required this.onAction,
  });

  /// The open occurrence, which carries the rule.
  final Task task;

  /// Null while loading.
  final List<Occurrence>? history;
  final List<Member> members;
  final DateTime today;
  final ValueChanged<Task> onOpen;
  final ValueChanged<SeriesAction> onAction;

  @override
  Widget build(BuildContext context) {
    final list = history;
    final rule = task.repeat;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.foreground,
        titleSpacing: 0,
        title: Text(
          task.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          PopupMenuButton<SeriesAction>(
            tooltip: 'Repeat options',
            position: PopupMenuPosition.under,
            color: AppColors.background,
            onSelected: onAction,
            icon: const Icon(Icons.more_vert, color: AppColors.mutedForeground),
            itemBuilder: (_) => [
              for (final (a, label) in [
                (SeriesAction.edit, 'edit repeat'),
                (SeriesAction.stop, 'stop repeating'),
                (SeriesAction.delete, 'delete'),
              ])
                PopupMenuItem(
                  value: a,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: a == SeriesAction.delete
                          ? AppColors.destructive
                          : AppColors.foreground,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
        children: [
          if (rule != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.repeat,
                    size: 16,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'creates a new task ${repeatSummary(rule, today)}, '
                      'when this task is done.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'OCCURRENCES',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: Color(0x806B7280),
            ),
          ),
          if (list == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final o in list)
              _OccurrenceRow(
                occurrence: o,
                assignee: members
                    .where((m) => m.user.id == o.task.assigneeId)
                    .firstOrNull
                    ?.user,
                today: today,
                onTap: () => onOpen(o.task),
              ),
        ],
      ),
    );
  }
}

/// "late · 2 days"; "late" when it slipped by hours, not days.
String lateLabel(DateTime finished, DateTime due) {
  final days = dateOnly(finished).difference(dateOnly(due)).inDays;
  return days < 1 ? 'late' : 'late · $days ${days == 1 ? 'day' : 'days'}';
}

class _OccurrenceRow extends StatelessWidget {
  const _OccurrenceRow({
    required this.occurrence,
    required this.assignee,
    required this.today,
    required this.onTap,
  });

  final Occurrence occurrence;
  final User? assignee;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = occurrence.task;
    final onTime = occurrence.onTime;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (t.code != null) ...[
                        Text(
                          t.code!,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        dayLabel(t.dueDate!, today),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (assignee != null) ...[
                        Avatar(assignee!),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          assignee?.name ?? 'no assignee',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                      if (onTime == null)
                        StatusPill(t.status)
                      else
                        Text(
                          onTime
                              ? 'on time'
                              : lateLabel(occurrence.finishedAt!, t.dueDate!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: onTime
                                ? AppColors.mutedForeground
                                : AppColors.destructive,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Kept in place when absent, so the results line up.
            Opacity(
              opacity: occurrence.proofUrl == null ? 0 : 1,
              child: const Icon(
                Icons.link,
                size: 16,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
