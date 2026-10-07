import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../notifications/notifications_screen.dart';
import '../home_cubit.dart';
import '../models.dart';
import '../widgets/view_options_sheet.dart';
import '../task_rules.dart';
import '../tasks_api.dart';
import 'create_task_sheet.dart';
import 'home_view.dart';
import 'task_detail_sheet.dart';

/// Connects [HomeView] to [HomeCubit] and shows its snackbars.
class HomePanel extends StatelessWidget {
  const HomePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();
    void snack(String text) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

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
            snack('Needs a proof — coming soon');
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
        onStartSearch: cubit.startSearch,
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
