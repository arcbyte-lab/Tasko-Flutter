import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/screens/discussion_screen.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);
  late FakeTasksApi api;

  Future<void> home(WidgetTester tester) async {
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
            child: HomePanel(onLogOut: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openList(WidgetTester tester) async {
    await home(tester);
    await tester.tap(find.byTooltip('Discussion'));
    await tester.pumpAndSettle();
  }

  testWidgets('the rail shows how many chats are unread, and opens the list', (
    tester,
  ) async {
    await home(tester);
    final badge = find.descendant(
      of: find.byType(Badge),
      matching: find.text('1'),
    ); // one chat, two messages
    expect(badge, findsOneWidget);
    await tester.tap(find.byTooltip('Discussion'));
    await tester.pumpAndSettle();
    expect(find.byType(DiscussionListView), findsOneWidget);
    expect(find.text('Fix login redirect'), findsOneWidget);
    expect(find.text('TW-0041'), findsOneWidget);
    expect(find.textContaining("Budi: Can this ship"), findsOneWidget);
    expect(find.byKey(const Key('unread-dot')), findsOneWidget);
  });

  testWidgets('a conversation shows the thread, hides the rails and reads it', (
    tester,
  ) async {
    await openList(tester);
    await tester.tap(find.text('Fix login redirect'));
    await tester.pumpAndSettle();
    expect(find.text('Start of conversation'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(
      find.text('Only happens on Safari for me. Chrome is fine.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Discussion'), findsNothing); // no rails here

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unread-dot')), findsNothing);
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(DiscussionListView), findsNothing);
    expect(find.byType(Badge), findsNothing); // the badge is gone
  });

  testWidgets('sending adds your bubble', (tester) async {
    await openList(tester);
    await tester.tap(find.text('Fix login redirect'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Shipping it');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Shipping it'), findsOneWidget);
    expect(find.textContaining('You', findRichText: true), findsOneWidget);
    expect(
      api.discussions().then((l) => l.discussions.first.lastBody),
      completion('Shipping it'),
    );
  });

  testWidgets('search narrows by task name or code', (tester) async {
    await openList(tester);
    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.pumpAndSettle();
    expect(find.text('no discussions yet'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'tw-0041');
    await tester.pumpAndSettle();
    expect(find.text('Fix login redirect'), findsOneWidget);
  });
}
