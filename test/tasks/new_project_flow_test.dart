import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/screens/new_project_sheet.dart';
import 'package:tasko/tasks/tasks_api.dart';

/// Mira with no roles anywhere: a plain member of everything.
class _PlainMember extends FakeTasksApi {
  _PlainMember({required super.today});

  @override
  Future<List<TaskTab>> myTabs() async => [
    for (final t in await super.myTabs()) TaskTab(t.kind, t.id, t.name),
  ];
}

void main() {
  final now = DateTime(2026, 10, 7, 10);

  Future<HomeCubit> pump(WidgetTester tester, FakeTasksApi api) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final cubit = HomeCubit(api, now: () => now)..load();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: RepositoryProvider<TasksApi>.value(
          value: api,
          child: BlocProvider.value(
            value: cubit,
            child: HomePanel(onLogOut: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('a division lead creates a project and lands on its tab', (
    tester,
  ) async {
    final cubit = await pump(tester, FakeTasksApi(today: now));
    await tester.tap(find.text('new project'));
    await tester.pumpAndSettle();

    // Only one division to choose from, so no division chip.
    expect(find.byTooltip('Division'), findsNothing);
    final done = find.widgetWithText(FilledButton, 'done');
    expect(tester.widget<FilledButton>(done).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Launch');
    await tester.pump();
    await tester.tap(done);
    await tester.pumpAndSettle();

    expect(find.byType(NewProjectForm), findsNothing);
    expect(cubit.state.activeTab?.name, 'Launch');
    expect(cubit.state.activeTab?.role, 'owner');
    expect(cubit.state.tabs.last, cubit.state.activeTab);
    expect(find.text('Launch'), findsWidgets);
  });

  testWidgets('a plain member does not see "new project"', (tester) async {
    await pump(tester, _PlainMember(today: now));
    expect(find.text('account settings'), findsOneWidget);
    expect(find.text('new project'), findsNothing);
  });
}
