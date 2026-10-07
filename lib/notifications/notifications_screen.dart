import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/app_theme.dart';
import '../tasks/models.dart';
import '../tasks/task_rules.dart';
import '../tasks/tasks_api.dart';
import 'notifications_cubit.dart';

/// Pushes the notifications screen. Completes when the user goes back.
Future<void> openNotifications(BuildContext context) {
  final api = context.read<TasksApi>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider(
        create: (_) => NotificationsCubit(api)..load(),
        child: const _NotificationsPanel(),
      ),
    ),
  );
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    return BlocBuilder<NotificationsCubit, List<AppNotification>?>(
      builder: (context, items) => NotificationsView(
        items: items,
        now: DateTime.now(),
        onTap: cubit.markRead,
        onMarkAllRead: cubit.markAllRead,
      ),
    );
  }
}

/// Unread under NEW, the rest under EARLIER (arcbyte lofi T4, hifi H3).
// ponytail: tapping a row only marks it read. Opening the task it names
// needs a task id in the notification data; add it with the real API.
class NotificationsView extends StatelessWidget {
  const NotificationsView({
    super.key,
    required this.items,
    required this.now,
    required this.onTap,
    required this.onMarkAllRead,
  });

  /// Null while loading.
  final List<AppNotification>? items;
  final DateTime now;
  final ValueChanged<AppNotification> onTap;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final list = items;
    final fresh = list?.where((n) => n.unread).toList() ?? [];
    final earlier = list?.where((n) => !n.unread).toList() ?? [];

    Widget section(String label, List<AppNotification> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(label, style: groupLabelStyle()),
        ),
        for (final n in rows)
          _Row(n: n, time: notificationTime(n.createdAt, now), onTap: onTap),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.foreground,
        titleSpacing: 0,
        title: const Text(
          'notifications',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          TextButton(
            onPressed: fresh.isEmpty ? null : onMarkAllRead,
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15),
            ),
            child: const Text('mark all read'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
          ? const Center(
              child: Text(
                'no notifications',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            )
          : ListView(
              children: [
                if (fresh.isNotEmpty) section('NEW', fresh),
                if (earlier.isNotEmpty) section('EARLIER', earlier),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.n, required this.time, required this.onTap});

  final AppNotification n;
  final String time;
  final ValueChanged<AppNotification> onTap;

  @override
  Widget build(BuildContext context) {
    final actor = n.actor;
    return Material(
      color: n.unread ? AppColors.muted : AppColors.background,
      child: InkWell(
        onTap: () => onTap(n),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 13, right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: n.unread ? AppColors.destructive : Colors.transparent,
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: actor == null
                    ? AppColors.secondary
                    : AppColors.accent,
                child: actor == null
                    ? const Icon(
                        Icons.notifications_none,
                        size: 18,
                        color: AppColors.mutedForeground,
                      )
                    : Text(
                        actor.name[0],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentForeground,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    n.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: n.unread
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
