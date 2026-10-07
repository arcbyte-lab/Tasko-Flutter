import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';
import 'package:tasko/tasks/widgets/task_row.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);

  Future<void> pump(WidgetTester tester, {String tab = 'tasko-web'}) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = FakeTasksApi(today: now);
    final cubit = HomeCubit(api, now: () => now);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: RepositoryProvider<TasksApi>.value(
          value: api,
          child: BlocProvider.value(
            value: cubit..load(),
            child: const HomePanel(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
  }

  // From the top of the task list, scroll down until [finder] shows.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    final list = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(list, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 100, scrollable: list);
  }

  Future<Finder> checkboxOf(WidgetTester tester, String title) async {
    await scrollTo(tester, find.text(title));
    return find.descendant(
      of: find.widgetWithText(TaskRow, title),
      matching: find.byType(InkResponse),
    );
  }

  testWidgets('home shows the header, calendar, tabs and grouped list', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('welcome, Mira'), findsOneWidget);
    expect(find.text('October'), findsOneWidget);
    expect(find.text('WORKSPACES'), findsOneWidget);
    expect(find.text('PROJECTS'), findsOneWidget);
    for (final g in ['OVERDUE', 'TODAY', 'TOMORROW', 'LATER']) {
      expect(find.text(g), findsOneWidget);
    }
    expect(find.text('Fix login redirect'), findsOneWidget);
    await scrollTo(tester, find.text('completed (3)'));
    expect(find.text('Set up analytics'), findsNothing);
  });

  testWidgets('tapping a day filters the list and shows the chip', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Day 14'));
    await tester.pumpAndSettle();
    expect(find.text('Oct 14'), findsOneWidget);
    expect(find.text('5 open'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('Fix login redirect'), findsNothing);

    await tester.tap(find.text('Oct 14'));
    await tester.pumpAndSettle();
    expect(find.text('Fix login redirect'), findsOneWidget);
  });

  testWidgets('an empty tab shows the empty state', (tester) async {
    await pump(tester, tab: 'tech');
    expect(find.text('no tasks here'), findsOneWidget);
    expect(find.text('0 open'), findsOneWidget);
  });

  testWidgets('ticking moves a task to completed; a proof task snacks', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(await checkboxOf(tester, 'Deploy staging'));
    await tester.pumpAndSettle();
    expect(find.text('Deploy staging'), findsNothing);
    await scrollTo(tester, find.text('completed (4)'));

    await tester.tap(await checkboxOf(tester, 'Upload release screenshots'));
    await tester.pump();
    expect(find.text('Needs a proof — coming soon'), findsOneWidget);
  });

  testWidgets('the full-screen calendar hides the list; a day collapses it', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Expand calendar'));
    await tester.pumpAndSettle();
    expect(find.text('WORKSPACES'), findsNothing);
    expect(find.text('Fix login redirect'), findsNothing);
    expect(find.text('5'), findsWidgets); // Oct 14's open count, in its cell

    await tester.tap(find.bySemanticsLabel('Day 14'));
    await tester.pumpAndSettle();
    expect(find.text('WORKSPACES'), findsOneWidget);
    expect(find.text('Oct 14'), findsOneWidget);
    expect(find.byTooltip('Expand calendar'), findsOneWidget);
  });

  testWidgets('the account menu shows name and email', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('mira@arcbyte.dev'), findsOneWidget);
    await tester.tap(find.text('log out'));
    await tester.pump();
    expect(find.text('action: log out'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
