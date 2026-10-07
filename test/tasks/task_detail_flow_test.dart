import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);
  late FakeTasksApi api;

  /// Home on [tab], then opens [task] from the list.
  Future<void> open(WidgetTester tester, String tab, String task) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    api = FakeTasksApi(today: now);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: RepositoryProvider<TasksApi>.value(
          value: api,
          child: BlocProvider(
            create: (_) => HomeCubit(api, now: () => now)..load(),
            child: const HomePanel(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(task),
      100,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text(task));
    await tester.pumpAndSettle();
  }

  Finder button(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  testWidgets('a team task shows its rows, sub-tasks and discussion', (
    tester,
  ) async {
    await open(tester, 'tasko-web', 'Fix login redirect');
    expect(find.text('tasko-web'), findsWidgets);
    expect(find.text('TW-0041'), findsOneWidget);
    for (final label in ['status', 'priority', 'due', 'assignee', 'proof']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('in progress'), findsWidgets);
    expect(find.text('required'), findsOneWidget);
    expect(find.text('SUB-TASKS (1/3)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('DISCUSSION'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text('Only happens on Safari for me. Chrome is fine.'),
      findsOneWidget,
    );

    await tester.tap(button('submit proof'));
    await tester.pump();
    expect(find.text('action: submit proof'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a personal task: no team rows; start, then done', (
    tester,
  ) async {
    await open(tester, 'private', 'Buy domain');
    expect(find.text('assignee'), findsNothing);
    expect(find.text('proof'), findsNothing);
    expect(find.text('DISCUSSION'), findsNothing);
    expect(find.text('SUB-TASKS (1/2)'), findsOneWidget);

    await tester.tap(button('start working'));
    await tester.pumpAndSettle();
    await tester.tap(button('mark done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('done · '), findsOneWidget);
  });

  testWidgets('a reviewer declines with a reason', (tester) async {
    await open(tester, 'tasko-web', 'Review PR #42');
    await tester.tap(button('decline'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(button('decline').last).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).last, 'Tests are missing');
    await tester.pump();
    await tester.tap(button('decline').last);
    await tester.pumpAndSettle();
    expect(api.reviews.single.$3, 'Tests are missing');
    expect(find.text('approve'), findsNothing); // back in progress
  });

  testWidgets('renaming saves when the sheet closes', (tester) async {
    await open(tester, 'tasko-web', 'Deploy staging');
    await tester.enterText(find.byType(TextField).first, 'Deploy prod');
    await tester.tapAt(const Offset(200, 20)); // the scrim
    await tester.pumpAndSettle();
    expect(find.text('Deploy prod'), findsOneWidget);
  });

  testWidgets('a member asks for an extension from the menu', (tester) async {
    await open(tester, 'tasko-app', 'Set up CI');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('members only'), findsOneWidget);
    await tester.tap(find.text('request due date extension'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('pick a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Due 12'));
    await tester.tap(button('done').last);
    await tester.pumpAndSettle();
    // keeps the current due time
    expect(find.text('Oct 12, 00:00'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Waiting on access');
    await tester.pump();
    await tester.tap(button('send request'));
    await tester.pumpAndSettle();
    expect(api.extensionRequests.single.$2, DateTime(2026, 10, 12));
    expect(find.text('extension requested'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
