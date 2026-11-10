import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../core/toast.dart';
import '../models.dart';
import '../task_detail_cubit.dart';
import '../task_rules.dart';
import '../tasks_api.dart';
import '../widgets/pickers.dart';
import 'repeat_screen.dart';
import '../widgets/reason_sheets.dart';
import '../widgets/task_row.dart';
import 'activity_screen.dart';

/// Opens Task Detail for [task]. Completes once the sheet has closed and
/// any title or note edit is saved, so the list can reload after it.
Future<void> showTaskDetailSheet(
  BuildContext context, {
  required TasksApi api,
  required Task task,
  required DateTime today,
}) async {
  final cubit = TaskDetailCubit(api, task)..load();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Keeps a tall sheet (keyboard up) clear of the status bar.
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _TaskDetailPanel(api: api, today: today),
    ),
  );
  await cubit.close();
}

/// Wires [TaskDetailView] to the cubit, the pickers and the follow-up sheets.
class _TaskDetailPanel extends StatelessWidget {
  const _TaskDetailPanel({required this.api, required this.today});

  /// The sheet's route sits above the provider, so it is handed down.
  final TasksApi api;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TaskDetailCubit>();
    return BlocBuilder<TaskDetailCubit, TaskDetailState>(
      builder: (context, state) {
        final task = state.task;
        return TaskDetailView(
          state: state,
          today: today,
          onEditName: cubit.editName,
          onEditNote: cubit.editNote,
          onEdit: cubit.startEdit,
          onSave: cubit.save,
          onCancelEdit: cubit.cancelEdit,
          onPriority: () async {
            final v = await showPicker<Priority>(
              context,
              PriorityPicker(initial: (state.draft ?? task).priority),
            );
            if (v != null) cubit.setPriority(v);
          },
          onDueDate: () async {
            final v = await showPicker<DateTime>(
              context,
              DueDatePicker(
                initial: (state.draft ?? task).dueDate,
                today: today,
              ),
            );
            if (v != null) cubit.setDueDate(v);
          },
          onRepeat: () async {
            final due = task.dueDate;
            if (due == null) return showToast(context, 'set a due date first');
            final v = await openRepeatScreen(
              context,
              initial: task.repeat,
              due: due,
            );
            if (v != null) await cubit.setRepeat(v.$1);
          },
          onAssignee: () async {
            final members = await api.membersOf(state.detail!.tab);
            if (!context.mounted) return;
            final v = await showPicker<Member>(
              context,
              AssigneePicker(
                members: members,
                initial: members
                    .where((m) => m.user.id == (state.draft ?? task).assigneeId)
                    .firstOrNull,
              ),
            );
            if (v != null) cubit.setAssignee(v);
          },
          onProof: () => showToast(context, 'action: choose proof type'),
          onTickSubtask: (sub) async {
            try {
              await cubit.tickSubtask(sub);
            } on ProofRequired {
              if (!context.mounted) return;
              final link = await showProofSheet(context);
              if (link != null) await cubit.tickSubtask(sub, proofUrl: link);
            }
          },
          onAddSubtask: cubit.addSubtask,
          onComment: cubit.addComment,
          onStartWorking: cubit.startWorking,
          onMarkDone: cubit.markDone,
          onSubmitProof: () async {
            final link = await showProofSheet(context);
            if (link != null) await cubit.submitProof(link);
          },
          onApprove: cubit.approve,
          onReject: () async {
            final reason = await showRejectSheet(context);
            if (reason != null) await cubit.reject(reason);
          },
          onRequestExtension: () async {
            final v = await showExtensionSheet(
              context,
              currentDue: task.dueDate,
              today: today,
            );
            if (v == null) return;
            await cubit.requestExtension(v.$1, v.$2);
            if (context.mounted) showToast(context, 'extension requested');
          },
          onArchive: () async {
            if (!await _confirmArchive(context)) return;
            await cubit.archive();
            if (context.mounted) Navigator.pop(context);
          },
          onProofList: () =>
              showProofListSheet(context, state.detail!.proofs, today),
          onActivity: () => openActivity(
            context,
            api: api,
            scope: TaskLog(task),
            today: today,
          ),
        );
      },
    );
  }
}

/// The detail panel and its action bar, drawn from plain [state].
class TaskDetailView extends StatelessWidget {
  const TaskDetailView({
    super.key,
    required this.state,
    required this.today,
    required this.onEditName,
    required this.onEditNote,
    required this.onEdit,
    required this.onSave,
    required this.onCancelEdit,
    required this.onPriority,
    required this.onDueDate,
    required this.onRepeat,
    required this.onAssignee,
    required this.onProof,
    required this.onTickSubtask,
    required this.onAddSubtask,
    required this.onComment,
    required this.onStartWorking,
    required this.onMarkDone,
    required this.onSubmitProof,
    required this.onApprove,
    required this.onReject,
    required this.onRequestExtension,
    required this.onArchive,
    this.onActivity,
    required this.onProofList,
  });

  final TaskDetailState state;
  final DateTime today;
  final ValueChanged<String> onEditName;
  final ValueChanged<String> onEditNote;

  /// Pencil, Save and Cancel: edit mode (hifi H13, decision 0018).
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancelEdit;
  final VoidCallback onPriority;
  final VoidCallback onDueDate;
  final VoidCallback onRepeat;
  final VoidCallback onAssignee;
  final VoidCallback onProof;
  final ValueChanged<Task> onTickSubtask;
  final ValueChanged<String> onAddSubtask;
  final ValueChanged<String> onComment;
  final VoidCallback onStartWorking;
  final VoidCallback onMarkDone;
  final VoidCallback onSubmitProof;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestExtension;
  final VoidCallback onArchive;

  /// Opens the list of every submitted proof.
  final VoidCallback onProofList;

  /// Opens the task's log; shown only when the server sets `canViewLog`.
  final VoidCallback? onActivity;

  @override
  Widget build(BuildContext context) {
    final editing = state.editing;
    final task = state.draft ?? state.task;
    final detail = state.detail;
    final team = !task.personal;
    // Assignees ask for an extension instead of editing the due date.
    final canEditDue = !(detail?.canRequestExtension ?? false);
    final media = MediaQuery.of(context);
    final action = state.action;

    final panel = Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.72),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            spreadRadius: -1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          _Header(tabName: detail?.tab.name ?? '', code: task.code),
          _EditableText(
            key: const ValueKey('title'),
            text: task.name,
            hint: 'title',
            keepIfBlank: true,
            onChanged: onEditName,
            editing: editing,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          _EditableText(
            key: const ValueKey('note'),
            text: task.description ?? '',
            hint: 'add note',
            onChanged: onEditNote,
            editing: editing,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          _DetailTabs(
            showDiscussion: team,
            brief: [
              _PropRow(
                icon: Icons.adjust,
                label: 'status',
                value: StatusPill(task.status),
              ),
              _PropRow(
                icon: Icons.flag_outlined,
                label: 'priority',
                onTap: editing ? onPriority : null,
                boxed: editing,
                value: Text(
                  task.priority.name,
                  style: TextStyle(
                    fontSize: 15,
                    color: task.priority == Priority.urgent
                        ? AppColors.destructive
                        : AppColors.foreground,
                  ),
                ),
              ),
              _PropRow(
                icon: Icons.calendar_today_outlined,
                label: 'due',
                onTap: editing && canEditDue ? onDueDate : null,
                boxed: editing && canEditDue,
                value: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    _dueText(task),
                    if (detail?.pendingExtension case final pending?) ...[
                      _PendingPill('${shortDate(pending, today)} pending'),
                    ],
                  ],
                ),
              ),
              // Only a workspace's own top-level tasks repeat (arcbyte decision 0009).
              if (detail?.tab.kind == TabKind.division && task.parentId == null)
                _PropRow(
                  icon: Icons.repeat,
                  label: 'repeat',
                  // Only a division lead sets it up; others see it (decision 0012).
                  onTap: detail!.canRepeat ? onRepeat : null,
                  value: Text(
                    task.repeat == null
                        ? 'does not repeat'
                        : repeatSummary(task.repeat!, today),
                    style: TextStyle(
                      fontSize: 15,
                      color: detail.canRepeat
                          ? null
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
              if (team) ...[
                _PropRow(
                  icon: Icons.person_outline,
                  label: 'assignee',
                  onTap: editing ? onAssignee : null,
                  boxed: editing,
                  value: _assignee(
                    editing ? state.draftAssignee : detail?.assignee,
                  ),
                ),
                _PropRow(
                  icon: Icons.attach_file,
                  label: 'proof',
                  onTap: onProof,
                  value: Text(
                    detail?.proof?.url ??
                        (task.requiredProofType == null ? 'none' : 'required'),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ],
            subtasks: detail == null
                ? null
                : _Subtasks(
                    subtasks: detail.subtasks,
                    onTick: onTickSubtask,
                    onAdd: onAddSubtask,
                  ),
            discussion: detail == null || !team
                ? null
                : _Discussion(
                    comments: detail.comments,
                    now: DateTime.now(),
                    onSend: onComment,
                  ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        12 + media.viewInsets.bottom + media.padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuickActions(
            onActivity: detail?.canViewLog ?? false ? onActivity : null,
            onProofList: detail != null && detail.proofs.isNotEmpty
                ? onProofList
                : null,
            extensionPending: detail?.pendingExtension != null,
            onRequestExtension: detail?.canRequestExtension ?? false
                ? onRequestExtension
                : null,
            onArchive: detail?.canArchive ?? false ? onArchive : null,
            editing: editing,
            onEdit:
                detail != null &&
                    (!team ||
                        task.assigneeId == state.me?.id ||
                        state.task.creatorId == state.me?.id ||
                        detail.canViewLog)
                ? onEdit
                : null,
          ),
          Flexible(child: panel),
          if (editing) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _EditBar(onSave: onSave, onCancel: onCancelEdit),
            ),
          ] else if (action != DetailAction.none &&
              media.viewInsets.bottom == 0) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _ActionBar(
                action: action,
                completedAt: task.completedAt,
                today: today,
                onStartWorking: onStartWorking,
                onMarkDone: onMarkDone,
                onSubmitProof: onSubmitProof,
                onApprove: onApprove,
                onReject: onReject,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dueText(Task task) {
    final due = task.dueDate;
    if (due == null) {
      return const Text(
        'no date',
        style: TextStyle(fontSize: 15, color: AppColors.placeholder),
      );
    }
    final text =
        '${shortDate(due, today)}, ${formatTime(TimeOfDay.fromDateTime(due))}';
    final overdue = isOverdue(task, today);
    return Text(
      overdue ? 'overdue · $text' : text,
      style: TextStyle(
        fontSize: 15,
        color: overdue ? AppColors.destructive : AppColors.foreground,
      ),
    );
  }

  Widget _assignee(User? user) {
    if (user == null) {
      return const Text(
        'nobody',
        style: TextStyle(fontSize: 15, color: AppColors.placeholder),
      );
    }
    final isMe = user.id == state.me?.id;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: isMe ? AppColors.primary : AppColors.accent,
          child: Text(
            isMe ? 'M' : user.name[0],
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isMe ? Colors.white : AppColors.accentForeground,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(isMe ? 'me' : user.name, style: const TextStyle(fontSize: 15)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tabName, required this.code});

  final String tabName;
  final String? code;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 12, color: AppColors.mutedForeground);
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Text(tabName, style: muted.copyWith(fontWeight: FontWeight.w500)),
          if (code != null) ...[
            const SizedBox(width: 6),
            Text(code!, style: muted.copyWith(fontFamily: fontMono)),
          ],
        ],
      ),
    );
  }
}

/// Brief / Sub tasks / Discussion under the note (hifi H11). A private task
/// has no Discussion.
class _DetailTabs extends StatefulWidget {
  const _DetailTabs({
    required this.brief,
    required this.subtasks,
    required this.discussion,
    required this.showDiscussion,
  });

  final List<Widget> brief;
  final Widget? subtasks;
  final Widget? discussion;
  final bool showDiscussion;

  @override
  State<_DetailTabs> createState() => _DetailTabsState();
}

class _DetailTabsState extends State<_DetailTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final names = [
      'Brief',
      'Sub tasks',
      if (widget.showDiscussion) 'Discussion',
    ];
    final body = switch (_index) {
      0 => Column(children: widget.brief),
      1 => widget.subtasks,
      _ => widget.discussion,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < names.length; i++)
                InkWell(
                  onTap: () => setState(() => _index = i),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
                    margin: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 2,
                          color: i == _index
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Text(
                      names[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: i == _index
                            ? AppColors.foreground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        body ??
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
      ],
    );
  }
}

/// 45px circles above the panel: history for leads, then extension and
/// archive for those who may (hifi H11). Edit and proof list come with H13.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    this.onActivity,
    this.onProofList,
    this.onRequestExtension,
    this.extensionPending = false,
    this.onEdit,
    this.editing = false,
    this.onArchive,
  });

  final VoidCallback? onEdit;

  /// The pencil is active (blue) while edit mode is on.
  final bool editing;
  final VoidCallback? onActivity;
  final VoidCallback? onProofList;
  final VoidCallback? onRequestExtension;

  /// A request is waiting for a decision: the button stays, greyed out.
  final bool extensionPending;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    Widget button(
      IconData icon,
      String tooltip,
      VoidCallback? onTap, {
      bool active = false,
      bool destructive = false,
      bool disabled = false,
    }) {
      if (onTap == null) return const SizedBox.shrink();
      final filled = active || destructive;
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: disabled ? null : onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: destructive
                  ? const Color(0xFFEF4444)
                  : active
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFF7F9FA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: disabled
                  ? AppColors.placeholder
                  : filled
                  ? Colors.white
                  : AppColors.mutedForeground,
            ),
          ),
        ),
      );
    }

    final buttons = [
      button(Icons.history, 'History', onActivity),
      button(Icons.upload_file_outlined, 'Submitted proofs', onProofList),
      button(
        Icons.update,
        extensionPending ? 'Extension pending' : 'Request extension',
        onRequestExtension,
        disabled: extensionPending,
      ),
      button(Icons.edit_outlined, 'Edit', onEdit, active: editing),
      button(
        Icons.delete_outline,
        'Archive task',
        onArchive,
        destructive: true,
      ),
    ];
    if (onActivity == null &&
        onProofList == null &&
        onEdit == null &&
        onRequestExtension == null &&
        onArchive == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 8,
        children: buttons.where((b) => b is! SizedBox).toList(),
      ),
    );
  }
}

class _EditableText extends StatefulWidget {
  const _EditableText({
    super.key,
    required this.text,
    required this.hint,
    required this.style,
    required this.onChanged,
    required this.editing,
    this.keepIfBlank = false,
  });

  final String text;
  final String hint;
  final TextStyle style;
  final ValueChanged<String> onChanged;

  /// Edit mode: a field box you can type in. Otherwise plain text.
  final bool editing;

  /// The title can't be blank: clearing it puts the old text back.
  final bool keepIfBlank;

  @override
  State<_EditableText> createState() => _EditableTextState();
}

class _EditableTextState extends State<_EditableText> {
  late final _controller = TextEditingController(text: widget.text);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) return;
      if (widget.keepIfBlank && _controller.text.trim().isEmpty) {
        _controller.text = widget.text;
      }
    });
  }

  @override
  void didUpdateWidget(_EditableText old) {
    super.didUpdateWidget(old);
    // Leaving edit mode (save or cancel) shows the task's own text again.
    if (old.editing && !widget.editing) _focus.unfocus();
    if ((!_focus.hasFocus || !widget.editing) &&
        widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    onChanged: widget.onChanged,
    maxLines: null,
    readOnly: !widget.editing,
    keyboardType: TextInputType.text,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => _focus.unfocus(),
    style: widget.style,
    decoration: widget.editing
        ? InputDecoration(
            hintText: widget.hint,
            hintStyle: widget.style.copyWith(color: AppColors.placeholder),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          )
        : InputDecoration.collapsed(
            hintText: widget.hint,
            hintStyle: widget.style.copyWith(color: AppColors.placeholder),
          ),
  );
}

class _PropRow extends StatelessWidget {
  const _PropRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.boxed = false,
  });

  final IconData icon;
  final String label;
  final Widget value;
  final VoidCallback? onTap;

  /// Edit mode: the value sits in a field box.
  final bool boxed;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.mutedForeground),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 12),
          // A long value (an overdue date on a narrow phone) is cut off.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: boxed
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: value,
                      )
                    : value,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A task's status as a pill, in the H4 colours.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      TaskStatus.inProgress => (AppColors.accent, AppColors.accentForeground),
      TaskStatus.review => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      TaskStatus.done => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
      TaskStatus.todo || TaskStatus.waiting => (
        AppColors.secondary,
        AppColors.secondaryForeground,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(status.label, style: TextStyle(fontSize: 13, color: fg)),
    );
  }
}

class _Subtasks extends StatefulWidget {
  const _Subtasks({
    required this.subtasks,
    required this.onTick,
    required this.onAdd,
  });

  final List<Task> subtasks;
  final ValueChanged<Task> onTick;
  final ValueChanged<String> onAdd;

  @override
  State<_Subtasks> createState() => _SubtasksState();
}

class _SubtasksState extends State<_Subtasks> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final subs = widget.subtasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        for (final t in subs)
          Row(
            children: [
              Transform.translate(
                offset: const Offset(-14, 0),
                child: TaskCheckbox(
                  status: t.status,
                  size: 16,
                  onTap: () => widget.onTick(t),
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(-14, 0),
                  child: Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 15,
                      color: t.status == TaskStatus.done
                          ? AppColors.mutedForeground
                          : AppColors.foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (_adding)
          TextField(
            autofocus: true,
            style: const TextStyle(fontSize: 15),
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'sub-task',
              hintStyle: TextStyle(color: AppColors.placeholder),
              isDense: true,
            ),
            onSubmitted: (v) {
              widget.onAdd(v);
              setState(() => _adding = false);
            },
            onTapOutside: (_) => setState(() => _adding = false),
          )
        else
          TextButton.icon(
            onPressed: () => setState(() => _adding = true),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('add sub-task'),
          ),
      ],
    );
  }
}

class _Discussion extends StatefulWidget {
  const _Discussion({
    required this.comments,
    required this.now,
    required this.onSend,
  });

  final List<Comment> comments;
  final DateTime now;
  final ValueChanged<String> onSend;

  @override
  State<_Discussion> createState() => _DiscussionState();
}

class _DiscussionState extends State<_Discussion> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    widget.onSend(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        for (final c in widget.comments)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    c.author.name[0],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentForeground,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: c.author.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '  ${relativeTime(c.createdAt, widget.now)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(c.body, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 4,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'write a comment…',
            hintStyle: const TextStyle(color: AppColors.placeholder),
            isDense: true,
            border: border,
            enabledBorder: border,
            suffixIcon: IconButton(
              tooltip: 'Send',
              onPressed: _send,
              icon: const Icon(Icons.send_outlined, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// The floating bar under the panel (arcbyte lofi ticket T9, hifi H4).
/// Cancel and Save while edit mode is on (decision 0018).
class _EditBar extends StatelessWidget {
  const _EditBar({required this.onSave, required this.onCancel});

  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      spacing: 8,
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
              shape: const StadiumBorder(),
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text('cancel'),
          ),
        ),
        Expanded(
          child: FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
              shape: const StadiumBorder(),
            ),
            child: const Text('save'),
          ),
        ),
      ],
    ),
  );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.action,
    required this.completedAt,
    required this.today,
    required this.onStartWorking,
    required this.onMarkDone,
    required this.onSubmitProof,
    required this.onApprove,
    required this.onReject,
  });

  final DetailAction action;
  final DateTime? completedAt;
  final DateTime today;
  final VoidCallback onStartWorking;
  final VoidCallback onMarkDone;
  final VoidCallback onSubmitProof;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder();
    const text = TextStyle(
      fontFamily: 'Inter',
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );
    Widget primary(String label, VoidCallback? onTap, {IconData? icon}) =>
        FilledButton.icon(
          onPressed: onTap,
          icon: icon == null ? null : Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(36),
            shape: shape,
            textStyle: text,
          ),
        );

    final child = switch (action) {
      DetailAction.startWorking => primary('start working', onStartWorking),
      DetailAction.markDone => primary('mark done', onMarkDone),
      DetailAction.submitProof => primary(
        'submit proof',
        onSubmitProof,
        icon: Icons.attach_file,
      ),
      DetailAction.waitingForReview => primary('waiting for review', null),
      DetailAction.review => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(36),
                shape: shape,
                textStyle: text,
                foregroundColor: AppColors.destructive,
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Text('reject'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: primary('approve', onApprove)),
        ],
      ),
      DetailAction.done => SizedBox(
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check, size: 18, color: Color(0xFF166534)),
            const SizedBox(width: 6),
            Text(
              completedAt == null
                  ? 'done'
                  : 'done · ${shortDate(completedAt!, today)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
      DetailAction.none => const SizedBox.shrink(),
    };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The grey "Oct 10 pending" pill by the due date (hifi H13).
class _PendingPill extends StatelessWidget {
  const _PendingPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
    ),
  );
}

/// The "Archive this task?" sheet; true on confirm.
Future<bool> _confirmArchive(BuildContext context) =>
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
                'Archive this task?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'It leaves every list. This cannot be undone from the app.',
                style: TextStyle(
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
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.destructive,
                      ),
                      child: const Text('Archive'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((v) => v ?? false);
