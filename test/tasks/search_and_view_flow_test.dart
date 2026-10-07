import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);

  Future<void> pump(WidgetTester tester) async {
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
            child: const HomePanel(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('tasko-web'));
    await tester.pumpAndSettle();
  }

  testWidgets('search narrows the list and hides headers and the FAB', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DEPLOY');
    await tester.pumpAndSettle();

    expect(find.text('Deploy staging'), findsOneWidget);
    expect(find.text('Fix login redirect'), findsNothing);
    expect(find.text('TOMORROW'), findsNothing);
    expect(find.byTooltip('Create task'), findsNothing);

    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(find.text('Fix login redirect'), findsOneWidget);
    expect(find.byTooltip('Create task'), findsOneWidget);
  });

  testWidgets('group by priority, filter by status, then reset', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('View options'));
    await tester.pumpAndSettle();
    expect(find.text('GROUP BY'), findsOneWidget);
    await tester.tap(find.text('priority').first); // the group-by chip
    await tester.tap(find.byTooltip('status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('in progress').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('apply'));
    await tester.pumpAndSettle();

    expect(find.text('URGENT'), findsOneWidget); // Fix login redirect
    expect(find.text('OVERDUE'), findsNothing);
    expect(find.text('3 open'), findsOneWidget); // the in-progress ones
    expect(find.text('Write onboarding copy'), findsNothing);

    // "any" can be picked again (a null menu value would count as cancel).
    await tester.tap(find.byTooltip('View options'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('any').last);
    await tester.pumpAndSettle();
    expect(find.text('in progress'), findsNothing);

    await tester.tap(find.text('reset'));
    await tester.tap(find.text('apply'));
    await tester.pumpAndSettle();
    expect(find.text('OVERDUE'), findsOneWidget);
    expect(find.text('12 open'), findsOneWidget);
  });

  testWidgets('switching tab drops filters but keeps grouping', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('View options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('status').first); // group by status
    await tester.tap(find.byTooltip('priority'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('urgent').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('apply'));
    await tester.pumpAndSettle();
    expect(find.text('1 open'), findsOneWidget);

    await tester.tap(find.text('tasko-app'));
    await tester.pumpAndSettle();
    expect(find.text('3 open'), findsOneWidget);
    expect(find.text('WAITING'), findsOneWidget);
  });
}
