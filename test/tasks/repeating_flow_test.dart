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
}
