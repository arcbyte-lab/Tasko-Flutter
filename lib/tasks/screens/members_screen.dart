import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../members_cubit.dart';
import '../models.dart';
import '../task_rules.dart';
import '../tasks_api.dart';
import '../widgets/pickers.dart';

/// Pushes [tab]'s members screen. Completes when the user goes back, or
/// right after they leave the project.
Future<void> openMembers(
  BuildContext context, {
  required TaskTab tab,
  required int meId,
}) {
  final api = context.read<TasksApi>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider(
        create: (_) => MembersCubit(api, tab)..load(),
        child: _MembersPanel(meId: meId),
      ),
    ),
  );
}

class _MembersPanel extends StatelessWidget {
  const _MembersPanel({required this.meId});

  final int meId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MembersCubit>();
    return BlocBuilder<MembersCubit, List<Member>?>(
      builder: (context, members) => MembersView(
        tab: cubit.tab,
        members: members,
        meId: meId,
        onAdd: () async {
          final user = await showPicker<User>(
            context,
            UserSearchPicker(
              search: cubit.search,
              exclude: {...?members?.map((m) => m.user.id)},
            ),
          );
          if (user != null) await cubit.add(user);
        },
        onRole: cubit.setRole,
        onRemove: cubit.remove,
        onLeave: (me) async {
          await cubit.remove(me);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

const _roles = ['owner', 'person-in-charge', 'member', 'viewer'];

/// The members with their roles. Owners and persons-in-charge get "add
/// member" and a menu per row; only an owner sees the owner role; the
/// viewer's own row offers "leave project" (arcbyte decision 0010). The
/// server checks every change.
class MembersView extends StatelessWidget {
  const MembersView({
    super.key,
    required this.tab,
    required this.members,
    required this.meId,
    required this.onAdd,
    required this.onRole,
    required this.onRemove,
    required this.onLeave,
  });

  final TaskTab tab;

  /// Null while loading.
  final List<Member>? members;
  final int meId;
  final VoidCallback onAdd;
  final void Function(Member m, String role) onRole;
  final ValueChanged<Member> onRemove;
  final ValueChanged<Member> onLeave;

  @override
  Widget build(BuildContext context) {
    final list = members;
    final myRole = list?.where((m) => m.user.id == meId).firstOrNull?.role;
    final manages = canManageMembers(
      TaskTab(tab.kind, tab.id, tab.name, role: myRole),
    );
    final owner = myRole == 'owner';

    /// What the viewer may do to [m], as menu label → action.
    List<(String, VoidCallback)> actions(Member m) {
      if (m.user.id == meId) return [('leave project', () => onLeave(m))];
      if (!manages || (m.role == 'owner' && !owner)) return [];
      return [
        for (final r in _roles)
          if (r != m.role && (r != 'owner' || owner))
            ('make $r', () => onRole(m, r)),
        ('remove', () => onRemove(m)),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.foreground,
        titleSpacing: 0,
        title: Text(
          '${tab.name} members',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          if (manages)
            TextButton(
              onPressed: onAdd,
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15),
              ),
              child: const Text('add member'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final m in list)
                  MemberRow(
                    user: m.user,
                    subtitle: m.role,
                    isMe: m.user.id == meId,
                    trailing: switch (actions(m)) {
                      [] => null,
                      final items => PopupMenuButton<VoidCallback>(
                        tooltip: 'Member options',
                        position: PopupMenuPosition.under,
                        color: AppColors.background,
                        onSelected: (action) => action(),
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.mutedForeground,
                        ),
                        itemBuilder: (_) => [
                          for (final (label, action) in items)
                            PopupMenuItem(
                              value: action,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 15,
                                  color:
                                      label == 'remove' ||
                                          label == 'leave project'
                                      ? AppColors.destructive
                                      : AppColors.foreground,
                                ),
                              ),
                            ),
                        ],
                      ),
                    },
                  ),
              ],
            ),
    );
  }
}
