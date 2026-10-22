import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/activity_cubit.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/screens/activity_screen.dart';
import 'package:tasko/tasks/http_tasks_api.dart' show ApiException;
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/screens/task_detail_sheet.dart';
import 'package:tasko/tasks/tasks_api.dart';

/// The activity logs (arcbyte decision 0014). In the fake, Mira is tech's
/// supervisor and tasko-web's owner, but a plain member of tasko-app.
void main() {
  final now = DateTime(2026, 10, 7, 10);

  Future<void> home(WidgetTester tester) async {
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
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  final activity = find.byTooltip('Activity');

  testWidgets(
    'the toolbar icon shows only on tabs whose log the viewer opens',
    (tester) async {
      await home(tester);
      final shown = <String, bool>{};
      for (final tab in ['private', 'tech', 'tasko-app', 'tasko-web']) {
        await tap(tester, find.text(tab));
        shown[tab] = activity.evaluate().isNotEmpty;
      }
      expect(shown, {
        'private': false,
        'tech': true,
        'tasko-app': false,
        'tasko-web': true,
      });
    },
  );

  testWidgets('the division log: its own rows and its projects’ member rows', (
    tester,
  ) async {
    await home(tester);
    await tap(tester, find.text('tech'));
    await tap(tester, activity);
    expect(find.text('tech activity'), findsOneWidget);
    expect(
      find.text('Mira deleted the repeat Rotate backups'),
      findsOneWidget,
      reason: 'newest first',
    );
    expect(find.textContaining('Deploy staging'), findsNothing);
  });

  testWidgets('tapping someone opens their own log', (tester) async {
    await home(tester);
    await tap(tester, find.text('tasko-web'));
    await tap(tester, activity);
    expect(find.text('tasko-web activity'), findsOneWidget);
    await tap(tester, find.byTooltip('Budi’s activity').first);
    expect(find.text('Budi activity'), findsOneWidget);
    expect(find.text('Budi sent Review PR #42 to review'), findsNWidgets(2));
  });

  testWidgets('a task row opens Task Detail', (tester) async {
    await home(tester);
    await tap(tester, find.text('tasko-web'));
    await tap(tester, activity);
    await tap(tester, find.text('Ana approved Fix footer links'));
    expect(find.byType(TaskDetailView), findsOneWidget);
  });

  testWidgets('a series row opens nothing', (tester) async {
    await home(tester);
    await tap(tester, find.text('tech'));
    await tap(tester, activity);
    await tap(tester, find.text('Mira deleted the repeat Rotate backups'));
    expect(find.byType(TaskDetailView), findsNothing);
  });

  test('the fake finds one team task: 404 when missing', () async {
    final api = FakeTasksApi(today: now);
    final deploy = (await api.tasksFor(
      FakeTasksApi.taskoWeb,
    )).firstWhere((t) => t.name == 'Deploy staging');
    expect((await api.task(deploy.id)).name, 'Deploy staging');
    await expectLater(
      api.task(999),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );
  });

  testWidgets('my activity, from the account menu', (tester) async {
    await home(tester);
    await tap(tester, find.byTooltip('Account'));
    await tap(tester, find.text('my activity'));
    expect(find.text('Mira activity'), findsOneWidget);
    expect(find.text('Mira deleted the repeat Rotate backups'), findsOneWidget);
  });

  testWidgets('Task Detail offers the task’s log only to the tab’s leads', (
    tester,
  ) async {
    await home(tester);
    await tap(tester, find.text('tasko-web'));
    await tap(tester, find.text('Deploy staging'));
    await tap(tester, find.byTooltip('More'));
    await tap(tester, find.text('activity'));
    expect(find.text('Deploy staging activity'), findsOneWidget);
    expect(
      find.text('Ana renamed Deploy to staging to Deploy staging'),
      findsOneWidget,
    );
    expect(
      find.text('Budi commented: Staging keys are in the vault'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Deploy staging').last)).pop();
    await tester.pumpAndSettle();
    await tap(tester, find.text('tasko-app'));
    await tap(tester, find.text('Set up CI'));
    await tap(tester, find.byTooltip('More'));
    expect(find.text('request due date extension'), findsOneWidget);
    expect(find.text('activity'), findsNothing);
  });

  group('the view', () {
    Future<void> view(
      WidgetTester tester,
      ActivityState state,
      VoidCallback onMore,
    ) => tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ActivityView(
          scope: const TabLog(FakeTasksApi.tech),
          state: state,
          today: now,
          onMore: onMore,
        ),
      ),
    );

    ActivityEntry at(int id, DateTime when) => ActivityEntry(
      id: id,
      action: 'task.started',
      actor: const User(id: 3, name: 'Budi'),
      actorName: 'Budi',
      subject: (type: 'task', id: 1, label: 'Rotate keys'),
      tab: FakeTasksApi.tech,
      createdAt: when,
    );

    testWidgets('an empty log says so', (tester) async {
      await view(tester, (items: const [], next: null), () {});
      expect(find.text('no activity yet'), findsOneWidget);
      expect(find.text('changes from now on show up here'), findsOneWidget);
      expect(find.text('load more'), findsNothing);
    });

    testWidgets(
      'rows grouped by day, and load more while there is a next page',
      (tester) async {
        var more = 0;
        await view(tester, (
          items: [
            at(3, DateTime(2026, 10, 7, 9, 5)),
            at(2, DateTime(2026, 10, 7, 8)),
            at(1, DateTime(2026, 10, 6, 17, 30)),
          ],
          next: 1,
        ), () => more++);
        expect(find.text('TODAY'), findsOneWidget);
        expect(find.text('YESTERDAY'), findsOneWidget);
        expect(find.text('Budi started Rotate keys'), findsNWidgets(3));
        expect(find.text('09:05'), findsOneWidget);
        await tester.tap(find.text('load more'));
        expect(more, 1);
      },
    );
  });
}
