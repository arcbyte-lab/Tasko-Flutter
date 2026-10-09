import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);

  Future<void> openSheet(WidgetTester tester, String tab) async {
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
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create task'));
    await tester.pumpAndSettle();
  }

  testWidgets('a team task: pick priority, date and assignee, then done', (
    tester,
  ) async {
    await openSheet(tester, 'tasko-web');
    for (final chip in ['due date', 'medium', 'me', 'no proof']) {
      expect(find.text(chip), findsOneWidget);
    }
    final done = find.widgetWithText(FilledButton, 'done');
    expect(tester.widget<FilledButton>(done).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Prepare demo');

    await tester.tap(find.text('medium'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('high'));
    await tester.tap(find.widgetWithText(FilledButton, 'done').last);
    await tester.pumpAndSettle();
    expect(find.text('high'), findsOneWidget);

    await tester.tap(find.text('due date'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Due 9'));
    await tester.tap(find.widgetWithText(FilledButton, 'done').last);
    await tester.pumpAndSettle();
    expect(find.text('Oct 9, 09:00'), findsOneWidget);

    await tester.tap(find.text('me'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'an');
    await tester.pumpAndSettle();
    expect(find.text('Budi'), findsNothing);
    await tester.tap(find.text('Ana'));
    await tester.tap(find.widgetWithText(FilledButton, 'done').last);
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'done'));
    await tester.pumpAndSettle();
    expect(find.text('new task'), findsNothing);
    expect(find.text('13 open'), findsOneWidget); // was 12
    await tester.scrollUntilVisible(
      find.text('Prepare demo'),
      100,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
  });

  testWidgets('cancel in a picker keeps the old value', (tester) async {
    await openSheet(tester, 'tasko-web');
    await tester.tap(find.text('medium'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('urgent'));
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();
    expect(find.text('medium'), findsOneWidget);
  });

  testWidgets('the proof chip shows the undecided-action message', (
    tester,
  ) async {
    await openSheet(tester, 'tasko-web');
    await tester.tap(find.text('no proof'));
    await tester.pump();
    expect(find.text('action: choose proof type'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('action: choose proof type'), findsNothing);
  });

  testWidgets('a personal task has only due date and priority', (tester) async {
    await openSheet(tester, 'private');
    expect(find.text('due date'), findsOneWidget);
    expect(find.text('medium'), findsOneWidget);
    expect(find.text('me'), findsNothing);
    expect(find.text('no proof'), findsNothing);
  });
}
