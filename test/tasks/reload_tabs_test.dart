import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);

  // A project made on the fake behind the app's back stands in for someone
  // else adding the viewer to one.
  test('reloadTabs picks up a new tab and keeps the selected one', () async {
    final api = FakeTasksApi(today: now);
    final cubit = HomeCubit(api, now: () => now);
    await cubit.load();
    await cubit.selectTab(FakeTasksApi.taskoWeb);
    final web = cubit.state.tasks;

    final added = await api.createProject(1, 'Launch');
    await cubit.reloadTabs();

    expect(cubit.state.tabs.last, added);
    expect(cubit.state.activeTab, FakeTasksApi.taskoWeb);
    expect(cubit.state.tasks, same(web)); // cached, not fetched again
    expect(cubit.state.tasksByTab[added], isEmpty);
  });

  testWidgets('a project shows up after closing notifications', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = FakeTasksApi(today: now);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: RepositoryProvider<TasksApi>.value(
          value: api,
          child: BlocProvider(
            create: (_) => HomeCubit(api, now: () => now)..load(),
            child: HomePanel(onLogOut: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications, unread'));
    await tester.pumpAndSettle();
    await api.createProject(1, 'Launch');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Launch'), findsOneWidget);
  });
}
