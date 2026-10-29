import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';

/// The repeating view (arcbyte decision 0012). Mira is tech's supervisor
/// in the fake, so she leads it.
void main() {
  final now = DateTime(2026, 10, 7, 10);
  late FakeTasksApi api;

  Future<void> home(
    WidgetTester tester, {
    Future<void> Function(FakeTasksApi api)? seed,
  }) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    api = FakeTasksApi(today: now);
    await seed?.call(api);
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

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.text(name));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  /// A weekly task in tech for Budi, due at [due].
  Future<Task> weekly(FakeTasksApi api, String name, DateTime due) async {
    final t = await api.createTask(
      FakeTasksApi.tech,
      name: name,
      priority: Priority.medium,
      dueDate: due,
      assigneeId: 3,
    );
    return api.updateTask(
      t.copyWith(repeat: () => const Repeat(weekdays: [1])),
    );
  }

  final repeating = find.byTooltip('Repeating');

  testWidgets('only a division lead sees the repeat icon', (tester) async {
    await home(tester);
    await tab(tester, 'tech');
    expect(repeating, findsOneWidget);
    await tab(tester, 'tasko-web');
    expect(repeating, findsNothing, reason: 'a project tab');
  });

  testWidgets('an empty division says how to start', (tester) async {
    await home(tester);
    await tab(tester, 'tech');
    await tester.tap(repeating);
    await tester.pumpAndSettle();
    expect(find.text('tech repeating'), findsOneWidget);
    expect(find.text('no repeating tasks yet'), findsOneWidget);
  });

  testWidgets('lists each repeating task with a dot per recent one', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await home(
      tester,
      seed: (api) async {
        // Due years ahead, so ticking it now is on time.
        final backup = await weekly(api, 'Backup check', DateTime(2030, 1, 7));
        await api.setStatus(backup, TaskStatus.done);
        final late = await weekly(api, 'Expense report', DateTime(2020, 1, 6));
        await api.setStatus(late, TaskStatus.done);
      },
    );
    await tab(tester, 'tech');
    await tester.tap(repeating);
    await tester.pumpAndSettle();

    expect(find.text('Expense report'), findsOneWidget);
    expect(
      find.text('every week on Mon · next Mon, Jan 13, 2020'),
      findsOneWidget,
    );
    expect(
      find.text('every week on Mon · next Mon, Jan 14, 2030'),
      findsOneWidget,
    );
    // Each row merges its dots into its own label.
    expect(find.bySemanticsLabel(RegExp(r'\bon time\b')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'\blate\b')), findsOneWidget);
    semantics.dispose();
  });

  /// Home → tech → the repeating view → [series]'s history.
  Future<void> history(WidgetTester tester, String series) async {
    await tab(tester, 'tech');
    await tester.tap(repeating);
    await tester.pumpAndSettle();
    await tester.tap(find.text(series).last);
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Repeat options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  /// Backup check, finished once on time; its next one is open.
  Future<void> backup(FakeTasksApi api) async {
    final t = await weekly(api, 'Backup check', DateTime(2030, 1, 7));
    await api.setStatus(t, TaskStatus.done);
  }

  testWidgets('a series shows its rule and every occurrence', (tester) async {
    await home(
      tester,
      seed: (api) async {
        await backup(api);
        final late = await weekly(api, 'Expense report', DateTime(2020, 1, 6));
        await api.setStatus(late, TaskStatus.done);
      },
    );
    await history(tester, 'Backup check');
    expect(
      find.text(
        'creates a new task every week on Mon, when this task is done.',
      ),
      findsOneWidget,
    );
    expect(find.text('Mon, Jan 14, 2030'), findsOneWidget, reason: 'open');
    expect(find.text('waiting'), findsOneWidget);
    expect(find.text('on time'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expense report').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('late · '), findsOneWidget);
  });

  testWidgets('stop repeating keeps the task, and the series as ended', (
    tester,
  ) async {
    await home(tester, seed: backup);
    await history(tester, 'Backup check');
    await menu(tester, 'stop repeating');
    expect(find.text('every week on Mon · ended'), findsOneWidget);

    await tester.tap(find.text('Backup check').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('ended. it created a new task'), findsOneWidget);
    expect(find.text('on time'), findsOneWidget, reason: 'history kept');
    await tester.tap(find.byTooltip('Repeat options'));
    await tester.pumpAndSettle();
    expect(find.text('stop repeating'), findsNothing);
    expect(find.text('edit repeat'), findsNothing);
    await tester.tap(find.text('delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('its tasks stay in the tab'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'delete'));
    await tester.pumpAndSettle();
    expect(find.text('no repeating tasks yet'), findsOneWidget);
    expect(
      (await api.tasksFor(
        FakeTasksApi.tech,
      )).where((t) => t.name == 'Backup check'),
      hasLength(2),
    );
  });

  testWidgets('delete asks first, then removes the waiting task', (
    tester,
  ) async {
    await home(tester, seed: backup);
    await history(tester, 'Backup check');
    await menu(tester, 'delete');
    expect(find.textContaining('finished tasks stay'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'delete'));
    await tester.pumpAndSettle();
    expect(find.text('no repeating tasks yet'), findsOneWidget);
    expect(
      (await api.tasksFor(FakeTasksApi.tech)).single.status,
      TaskStatus.done,
      reason: 'the finished one stays',
    );
  });

  testWidgets('a started task cannot be deleted, only stopped', (tester) async {
    await home(
      tester,
      seed: (api) async {
        await backup(api);
        final open = (await api.tasksFor(
          FakeTasksApi.tech,
        )).singleWhere((t) => t.repeat != null);
        await api.setStatus(open, TaskStatus.inProgress);
      },
    );
    await history(tester, 'Backup check');
    await menu(tester, 'delete');
    await tester.tap(find.widgetWithText(FilledButton, 'delete'));
    await tester.pump();
    expect(
      find.text('Already started — stop repeating instead'),
      findsOneWidget,
    );
    expect(find.text('Backup check'), findsOneWidget, reason: 'still here');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a lead gets a repeat chip, which needs a due date', (
    tester,
  ) async {
    await home(tester);
    await tab(tester, 'tech');
    await tester.tap(find.byTooltip('Create task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Backup check');
    await tester.tap(find.text('repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('every week on'), findsOneWidget);
    expect(find.text('a repeating task needs a due date'), findsOneWidget);
    final done = find.widgetWithText(FilledButton, 'done');
    expect(tester.widget<FilledButton>(done).onPressed, isNull);
  });
}
