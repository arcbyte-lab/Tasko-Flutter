import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/toast.dart';
import '../../notifications/notifications_screen.dart';
import '../home_cubit.dart';
import '../models.dart';
import '../widgets/reason_sheets.dart';
import '../widgets/view_options_sheet.dart';
import '../task_rules.dart';
import '../tasks_api.dart';
import 'create_task_sheet.dart';
import 'home_view.dart';
import 'members_screen.dart';
import 'repeating_screen.dart';
import 'series_screen.dart';
import 'new_project_sheet.dart';
import 'task_detail_sheet.dart';

/// Connects [HomeView] to [HomeCubit] and shows its snackbars.
class HomePanel extends StatelessWidget {
  const HomePanel({super.key, required this.onLogOut});

  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) => HomeView(
        state: state,
        onSelectTab: cubit.selectTab,
        onDayTap: cubit.selectDay,
        onClearDay: cubit.clearDay,
        onMonthChange: cubit.changeMonth,
        onToggleCompleted: cubit.toggleCompleted,
        onTick: (task) async {
          try {
            await cubit.tick(task);
          } on ProofRequired {
            if (!context.mounted) return;
            final link = await showProofSheet(context);
            if (link != null) await cubit.tick(task, proofUrl: link);
          }
        },
        onCreate: () async {
          final task = await showCreateTaskSheet(
            context,
            api: context.read<TasksApi>(),
            tab: state.activeTab!,
            today: state.today,
          );
          if (task != null) await cubit.reload();
        },
        onToggleCalendar: cubit.toggleCalendar,
        // No account screen exists yet (arcbyte lofi T12 pattern).
        onAccountSettings: () => showToast(context, 'action: account settings'),
        onNewProject: state.tabs.any(canCreateProject)
            ? () async {
                final tab = await showNewProjectSheet(
                  context,
                  api: context.read<TasksApi>(),
                  divisions: state.tabs.where(canCreateProject).toList(),
                  today: state.today,
                );
                if (tab != null) await cubit.addTab(tab);
              }
            : null,
        onLogOut: onLogOut,
        onStartSearch: cubit.startSearch,
        onMembers: state.activeTab?.kind == TabKind.project
            ? () async {
                await openMembers(
                  context,
                  tab: state.activeTab!,
                  meId: state.user!.id,
                );
                // Joined, left or re-roled: the tabs and roles may differ.
                await cubit.reloadTabs();
              }
            : null,
        onRepeating: canManageRepeats(state.activeTab ?? TaskTab.private)
            ? () async {
                // Pushed routes sit above the provider: hand the api down.
                final api = context.read<TasksApi>();
                await openRepeating(
                  context,
                  tab: state.activeTab!,
                  members: state.members,
                  today: state.today,
                  onNew: (context) => showCreateTaskSheet(
                    context,
                    api: api,
                    tab: state.activeTab!,
                    today: state.today,
                  ),
                  onOpen: (context, series) => openSeries(
                    context,
                    api: api,
                    series: series,
                    members: state.members,
                    today: state.today,
                  ),
                );
                await cubit.reload();
              }
            : null,
        onSearch: cubit.search,
        onStopSearch: cubit.stopSearch,
        onViewOptions: () async {
          final v = await showViewOptionsSheet(
            context,
            current: state.view,
            personal: state.activeTab?.kind == TabKind.private,
            members: state.members,
            meId: state.user!.id,
          );
          if (v != null) cubit.setView(v);
        },
        onNotifications: () async {
          await openNotifications(context);
          // Someone may have added the viewer to a project (decision 0010).
          await cubit.reloadTabs();
          await cubit.reload();
        },
        onOpen: (task) async {
          await showTaskDetailSheet(
            context,
            api: context.read<TasksApi>(),
            task: task,
            today: state.today,
          );
          await cubit.reload();
        },
      ),
    );
  }
}
