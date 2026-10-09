import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../core/toast.dart';
import '../models.dart';
import '../task_detail_cubit.dart';
import '../task_rules.dart';
import '../tasks_api.dart';
import '../widgets/pickers.dart';
import '../widgets/reason_sheets.dart';
import '../widgets/task_row.dart';

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
      child: _TaskDetailPanel(today: today),
    ),
  );
  await cubit.flush();
  await cubit.close();
}

/// Wires [TaskDetailView] to the cubit, the pickers and the follow-up sheets.
class _TaskDetailPanel extends StatelessWidget {
  const _TaskDetailPanel({required this.today});

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
          onCommit: cubit.flush,
          onPriority: () async {
            final v = await showPicker<Priority>(
              context,
              PriorityPicker(initial: task.priority),
            );
            if (v != null) await cubit.setPriority(v);
          },
          onDueDate: () async {
            final v = await showPicker<DateTime>(
              context,
              DueDatePicker(initial: task.dueDate, today: today),
            );
            if (v != null) await cubit.setDueDate(v);
          },
          onAssignee: () async {
            final members = await context.read<TasksApi>().membersOf(
              state.detail!.tab,
            );
            if (!context.mounted) return;
            final v = await showPicker<Member>(
              context,
              AssigneePicker(
                members: members,
                initial: members
                    .where((m) => m.user.id == task.assigneeId)
                    .firstOrNull,
              ),
            );
            if (v != null) await cubit.setAssignee(v);
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
          onArchive: () => showToast(context, 'action: archive task'),
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
    required this.onCommit,
    required this.onPriority,
    required this.onDueDate,
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
  });

  final TaskDetailState state;
  final DateTime today;
  final ValueChanged<String> onEditName;
  final ValueChanged<String> onEditNote;

  /// Saves the title and note drafts; called on blur.
  final VoidCallback onCommit;
  final VoidCallback onPriority;
  final VoidCallback onDueDate;
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

  @override
  Widget build(BuildContext context) {
    final task = state.task;
    final detail = state.detail;
    final team = !task.personal;
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
          _Header(
            tabName: detail?.tab.name ?? '',
            code: task.code,
            canExtend: detail?.canRequestExtension ?? false,
            canArchive: detail?.canArchive ?? false,
            onRequestExtension: onRequestExtension,
            onArchive: onArchive,
          ),
          _EditableText(
            key: const ValueKey('title'),
            text: task.name,
            hint: 'title',
            keepIfBlank: true,
            onChanged: onEditName,
            onBlur: onCommit,
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
            onBlur: onCommit,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          _PropRow(
            icon: Icons.adjust,
            label: 'status',
            value: _StatusPill(task.status),
          ),
          _PropRow(
            icon: Icons.flag_outlined,
            label: 'priority',
            onTap: onPriority,
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
            onTap: onDueDate,
            value: _dueText(task),
          ),
          if (team) ...[
            _PropRow(
              icon: Icons.person_outline,
              label: 'assignee',
              onTap: onAssignee,
              value: _assignee(detail?.assignee),
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
          if (detail == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _Subtasks(
              subtasks: detail.subtasks,
              onTick: onTickSubtask,
              onAdd: onAddSubtask,
            ),
            if (team)
              _Discussion(
                comments: detail.comments,
                now: DateTime.now(),
                onSend: onComment,
              ),
          ],
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
          Flexible(child: panel),
          if (action != DetailAction.none && media.viewInsets.bottom == 0) ...[
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
  const _Header({
    required this.tabName,
    required this.code,
    required this.canExtend,
    required this.canArchive,
    required this.onRequestExtension,
    required this.onArchive,
  });

  final String tabName;
  final String? code;
  final bool canExtend;
  final bool canArchive;
  final VoidCallback onRequestExtension;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 12, color: AppColors.mutedForeground);
    Widget item(String title, String who, {Color? color}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 15, color: color ?? AppColors.foreground),
        ),
        Text(who, style: muted),
      ],
    );
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Text(tabName, style: muted.copyWith(fontWeight: FontWeight.w500)),
          if (code != null) ...[
            const SizedBox(width: 6),
            Text(code!, style: muted.copyWith(fontFamily: fontMono)),
          ],
          const Spacer(),
          if (canExtend || canArchive)
            PopupMenuButton<VoidCallback>(
              tooltip: 'More',
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.mutedForeground,
              ),
              color: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppColors.border),
              ),
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                if (canExtend)
                  PopupMenuItem(
                    value: onRequestExtension,
                    child: item('request due date extension', 'members only'),
                  ),
                if (canArchive)
                  PopupMenuItem(
                    value: onArchive,
                    child: item(
                      'archive task',
                      'author only',
                      color: AppColors.destructive,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A text field that looks like plain text. Edits go out as drafts and are
/// saved on blur.
class _EditableText extends StatefulWidget {
  const _EditableText({
    super.key,
    required this.text,
    required this.hint,
    required this.style,
    required this.onChanged,
    required this.onBlur,
    this.keepIfBlank = false,
  });

  final String text;
  final String hint;
  final TextStyle style;
  final ValueChanged<String> onChanged;
  final VoidCallback onBlur;

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
      widget.onBlur();
    });
  }

  @override
  void didUpdateWidget(_EditableText old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.text != _controller.text) {
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
    keyboardType: TextInputType.text,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => _focus.unfocus(),
    style: widget.style,
    decoration: InputDecoration.collapsed(
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
  });

  final IconData icon;
  final String label;
  final Widget value;
  final VoidCallback? onTap;

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
                child: value,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

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
    final done = subs.where((t) => t.status == TaskStatus.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          subs.isEmpty ? 'SUB-TASKS' : 'SUB-TASKS ($done/${subs.length})',
          style: groupLabelStyle(),
        ),
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
        const SizedBox(height: 20),
        Text('DISCUSSION', style: groupLabelStyle()),
        const SizedBox(height: 8),
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
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
            minimumSize: const Size.fromHeight(44),
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
                minimumSize: const Size.fromHeight(44),
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
        height: 44,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
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
