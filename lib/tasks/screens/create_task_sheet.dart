import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../core/toast.dart';
import '../create_task_cubit.dart';
import '../models.dart';
import '../task_rules.dart';
import '../tasks_api.dart';
import '../widgets/pickers.dart';
import '../widgets/task_row.dart';
import 'repeat_screen.dart';

/// Opens the create sheet for [tab]. Resolves to the new task, or null when
/// the sheet is dismissed. Given [tabs] (from "my tasks", decision 0017), a
/// chip lets the user pick which of them it goes in.
Future<Task?> showCreateTaskSheet(
  BuildContext context, {
  required TasksApi api,
  required TaskTab tab,
  required DateTime today,
  List<TaskTab>? tabs,
}) => showModalBottomSheet<Task>(
  context: context,
  isScrollControlled: true,
  // Keeps a tall sheet (keyboard up) clear of the status bar.
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: AppColors.background,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  ),
  builder: (_) => BlocProvider(
    create: (_) => CreateTaskCubit(api, tab)..load(),
    child: _CreateTaskPanel(today: today, tabs: tabs),
  ),
);

/// Wires [CreateTaskForm] to the cubit and opens the pickers.
class _CreateTaskPanel extends StatelessWidget {
  const _CreateTaskPanel({required this.today, this.tabs});

  final DateTime today;
  final List<TaskTab>? tabs;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreateTaskCubit>();
    return BlocBuilder<CreateTaskCubit, CreateTaskState>(
      builder: (context, state) => CreateTaskForm(
        state: state,
        today: today,
        isTeam: cubit.isTeam,
        canRepeat: canManageRepeats(cubit.tab),
        onTab: tabs == null
            ? null
            : () async {
                final v = await showPicker<TaskTab>(
                  context,
                  TabPicker(tabs: tabs!, initial: cubit.tab),
                );
                if (v != null) cubit.setTab(v);
              },
        onName: cubit.setName,
        onNote: cubit.setNote,
        onDueDate: () async {
          final v = await showPicker<DateTime>(
            context,
            DueDatePicker(initial: state.dueDate, today: today),
          );
          if (v != null) cubit.setDueDate(v);
        },
        onPriority: () async {
          final v = await showPicker<Priority>(
            context,
            PriorityPicker(initial: state.priority),
          );
          if (v != null) cubit.setPriority(v);
        },
        onAssignee: () async {
          final v = await showPicker<Member>(
            context,
            AssigneePicker(members: state.members, initial: state.assignee),
          );
          if (v != null) cubit.setAssignee(v);
        },
        onRepeat: () async {
          // Until a due date is picked, the rule starts from today.
          final v = await openRepeatScreen(
            context,
            initial: state.repeat,
            due: state.dueDate ?? today,
          );
          if (v != null) cubit.setRepeat(v.$1);
        },
        // Proof types are not decided yet (arcbyte lofi ticket T12).
        onProof: () => showToast(context, 'action: choose proof type'),
        onDone: () async {
          final task = await cubit.submit();
          if (task != null && context.mounted) Navigator.pop(context, task);
        },
      ),
    );
  }
}

/// Title, note, the chips, and "done". Personal tasks get only the due date
/// and priority chips; a division lead also gets repeat (decision 0012).
class CreateTaskForm extends StatelessWidget {
  const CreateTaskForm({
    super.key,
    required this.state,
    required this.today,
    required this.isTeam,
    this.canRepeat = false,
    this.onTab,
    required this.onName,
    required this.onNote,
    required this.onDueDate,
    required this.onPriority,
    required this.onAssignee,
    required this.onProof,
    this.onRepeat,
    required this.onDone,
  });

  final CreateTaskState state;
  final DateTime today;
  final bool isTeam;
  final bool canRepeat;

  /// Picks the tab; null hides the tab chip (any tab but "my tasks").
  final VoidCallback? onTab;
  final ValueChanged<String> onName;
  final ValueChanged<String> onNote;
  final VoidCallback onDueDate;
  final VoidCallback onPriority;
  final VoidCallback onAssignee;
  final VoidCallback onProof;
  final VoidCallback? onRepeat;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final due = state.dueDate;
    final assignee = state.assignee;
    final isMe = assignee != null && assignee == state.members.firstOrNull;
    const placeholder = TextStyle(color: AppColors.placeholder);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              autofocus: true,
              onChanged: onName,
              textInputAction: TextInputAction.next,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration.collapsed(
                hintText: 'new task',
                hintStyle: placeholder,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: onNote,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.mutedForeground,
              ),
              decoration: const InputDecoration.collapsed(
                hintText: 'add note',
                hintStyle: TextStyle(color: AppColors.mutedForeground),
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onTab != null)
                  SheetChip(
                    icon: Icons.folder_outlined,
                    label: '${state.tab.name} ▾',
                    onTap: onTab,
                  ),
                SheetChip(
                  icon: Icons.calendar_today_outlined,
                  label: due == null
                      ? 'due date'
                      : '${shortDate(due, today)}, '
                            '${formatTime(TimeOfDay.fromDateTime(due))}',
                  onTap: onDueDate,
                ),
                if (canRepeat)
                  SheetChip(
                    icon: Icons.repeat,
                    label: state.repeat == null
                        ? 'repeat'
                        : repeatSummary(state.repeat!, today),
                    onTap: onRepeat,
                  ),
                SheetChip(
                  icon: Icons.flag_outlined,
                  iconColor: TaskRow.priorityColor(state.priority),
                  label: state.priority.name,
                  onTap: onPriority,
                ),
                if (isTeam) ...[
                  SheetChip(
                    icon: Icons.person_outline,
                    label: isMe ? 'me' : (assignee?.user.name ?? 'assignee'),
                    onTap: state.members.isEmpty ? null : onAssignee,
                  ),
                  SheetChip(
                    icon: Icons.attach_file,
                    label: 'no proof',
                    onTap: onProof,
                  ),
                ],
              ],
            ),
            if (state.missingDue) ...[
              const SizedBox(height: 8),
              const Text(
                'a repeating task needs a due date',
                style: TextStyle(fontSize: 12, color: AppColors.destructive),
              ),
            ],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: state.canSubmit ? onDone : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// H1 chip: #F3F4F6, radius 6, no border, 13 medium. Shared by the create
/// sheets.
class SheetChip extends StatelessWidget {
  const SheetChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = AppColors.mutedForeground,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.secondary,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryForeground,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
