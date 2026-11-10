import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../core/toast.dart';
import '../discussion_cubit.dart';
import '../models.dart';
import '../task_rules.dart';
import '../tasks_api.dart';
import '../widgets/rails.dart';
import 'repeating_screen.dart' show Avatar;
import 'task_detail_sheet.dart';

/// Pushes the Discussion list (hifi H13), opened from the Discussion rail.
/// Home pops back to the screen below. Pushed routes sit above the provider,
/// so [api] is handed down.
Future<void> openDiscussions(
  BuildContext context, {
  required TasksApi api,
  required DateTime today,
  required VoidCallback onNewTask,
  VoidCallback? onNewProject,
}) async {
  final me = await api.me();
  final cubit = DiscussionListCubit(api)..load();
  if (!context.mounted) return cubit.close();
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _DiscussionListPage(
          api: api,
          me: me,
          today: today,
          onNewTask: onNewTask,
          onNewProject: onNewProject,
        ),
      ),
    ),
  );
  await cubit.close();
}

class _DiscussionListPage extends StatelessWidget {
  const _DiscussionListPage({
    required this.api,
    required this.me,
    required this.today,
    required this.onNewTask,
    this.onNewProject,
  });

  final TasksApi api;
  final User me;
  final DateTime today;
  final VoidCallback onNewTask;
  final VoidCallback? onNewProject;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DiscussionListCubit>();
    return BlocBuilder<DiscussionListCubit, DiscussionList?>(
      builder: (context, list) => DiscussionListView(
        list: list,
        me: me,
        now: DateTime.now(),
        chatsUnread: list?.unread ?? 0,
        onSearch: cubit.load,
        onOpen: (d) async {
          final task = await api.task(d.taskId);
          if (!context.mounted) return;
          await openConversation(context, api: api, task: task, today: today);
          await cubit.load();
        },
        onHome: () => Navigator.of(context).pop(),
        onNewTask: onNewTask,
        onNewProject: onNewProject,
      ),
    );
  }
}

/// The list, drawn from plain state.
class DiscussionListView extends StatelessWidget {
  const DiscussionListView({
    super.key,
    required this.list,
    required this.me,
    required this.now,
    required this.chatsUnread,
    required this.onSearch,
    required this.onOpen,
    required this.onHome,
    required this.onNewTask,
    this.onNewProject,
  });

  /// Null while loading.
  final DiscussionList? list;
  final User me;
  final DateTime now;
  final int chatsUnread;
  final ValueChanged<String> onSearch;
  final ValueChanged<Discussion> onOpen;
  final VoidCallback onHome;
  final VoidCallback onNewTask;
  final VoidCallback? onNewProject;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: Column(
      children: [
        const _Header('DISCUSSION'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: onSearch,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by task name or code',
              hintStyle: const TextStyle(color: AppColors.placeholder),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.mutedForeground,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: switch (list) {
            null => const Center(child: CircularProgressIndicator()),
            DiscussionList(discussions: []) => const Center(
              child: Text(
                'no discussions yet',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            final l => ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                for (final d in l.discussions)
                  _Row(d, me: me, now: now, onTap: () => onOpen(d)),
              ],
            ),
          },
        ),
      ],
    ),
    bottomNavigationBar: Rails(
      active: RailsItem.discussion,
      discussionBadge: chatsUnread,
      onHome: onHome,
      onNewTask: onNewTask,
      onNewProject: onNewProject,
    ),
  );
}

/// "DISCUSSION" on black, as the top bar of home.
class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black,
    padding: EdgeInsets.fromLTRB(
      16,
      MediaQuery.viewPaddingOf(context).top,
      16,
      0,
    ),
    height: 61 + MediaQuery.viewPaddingOf(context).top,
    alignment: Alignment.centerLeft,
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -1,
        color: Colors.white,
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(
    this.d, {
    required this.me,
    required this.now,
    required this.onTap,
  });

  final Discussion d;
  final User me;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = d.unread > 0;
    final mine = d.lastAuthor.id == me.id;
    final text = d.lastBody.isEmpty ? 'sent an attachment' : d.lastBody;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? AppColors.muted : null,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Person(d.lastAuthor, me: mine, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        relativeTime(d.lastAt, now),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          key: const Key('unread-dot'),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.destructive,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (d.code != null)
                    Text(
                      d.code!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  Text(
                    '${mine ? 'You' : d.lastAuthor.name}: $text',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
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

/// The viewer's avatar is solid blue; everyone else's is the light one.
class _Person extends StatelessWidget {
  const _Person(this.user, {required this.me, required this.radius});

  final User user;
  final bool me;
  final double radius;

  @override
  Widget build(BuildContext context) => me
      ? CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF2563EB),
          child: Text(
            user.name[0].toUpperCase(),
            style: TextStyle(
              fontSize: radius - 4,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        )
      : Avatar(user, radius: radius);
}

/// Pushes one conversation. The rails are hidden here. Opening it marks it
/// read.
Future<void> openConversation(
  BuildContext context, {
  required TasksApi api,
  required Task task,
  required DateTime today,
}) async {
  final cubit = ConversationCubit(api, task)..load();
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<ConversationCubit, ConversationState>(
          builder: (context, state) => ConversationView(
            task: task,
            state: state,
            now: DateTime.now(),
            onSend: cubit.send,
            onAttach: () => showToast(context, 'attachments come with Media'),
            onOpenTask: () => showTaskDetailSheet(
              context,
              api: api,
              task: task,
              today: today,
            ),
          ),
        ),
      ),
    ),
  );
  await cubit.close();
}

/// A task's comments as a chat (hifi H13).
class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.task,
    required this.state,
    required this.now,
    required this.onSend,
    required this.onAttach,
    required this.onOpenTask,
  });

  final Task task;
  final ConversationState state;
  final DateTime now;
  final Future<void> Function(String text) onSend;
  final VoidCallback onAttach;
  final VoidCallback onOpenTask;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _field.text;
    _field.clear();
    await widget.onSend(text);
  }

  String _day(DateTime d) {
    final today = dateOnly(widget.now);
    final day = dateOnly(d);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return shortDate(day, today);
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.state.me;
    final items = <Widget>[
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'Start of conversation',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    ];
    DateTime? last;
    for (final c in widget.state.comments) {
      final day = dateOnly(c.createdAt);
      if (last != day) {
        items.add(_DatePill(_day(c.createdAt)));
        last = day;
      }
      items.add(
        _Bubble(
          c,
          mine: c.author.id == me?.id,
          label: relativeTime(c.createdAt, widget.now),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.task.code != null)
                          Text(
                            widget.task.code!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onOpenTask,
                    tooltip: 'Open task',
                    icon: const Icon(
                      Icons.open_in_new,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.state.loading
                  ? const Center(child: CircularProgressIndicator())
                  // Newest at the bottom, where the field is.
                  : ListView(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: items.reversed.toList(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _field,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Write feedback or a progress update',
                  hintStyle: const TextStyle(color: AppColors.placeholder),
                  prefixIcon: IconButton(
                    onPressed: widget.onAttach,
                    tooltip: 'Attach',
                    icon: const Icon(
                      Icons.attach_file,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  suffixIcon: IconButton(
                    onPressed: _send,
                    tooltip: 'Send',
                    icon: const Icon(
                      Icons.send_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.secondaryForeground,
          ),
        ),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.c, {required this.mine, required this.label});

  final Comment c;
  final bool mine;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.accent : AppColors.secondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: mine ? 'You' : c.author.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: mine ? AppColors.accentForeground : null,
                    ),
                  ),
                  TextSpan(
                    text: '  $label',
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              c.body,
              style: TextStyle(
                fontSize: 15,
                color: mine ? AppColors.accentForeground : AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: mine
            ? [
                const SizedBox(width: 48),
                bubble,
                const SizedBox(width: 8),
                _Person(c.author, me: true, radius: 16),
              ]
            : [
                _Person(c.author, me: false, radius: 16),
                const SizedBox(width: 8),
                bubble,
                const SizedBox(width: 48),
              ],
      ),
    );
  }
}
