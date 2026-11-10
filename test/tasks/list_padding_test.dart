import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';

/// A ListView adds the screen's top inset (the status bar) as padding unless
/// told not to, which left a blank gap between the list toolbar and the first
/// group on a real phone.
void main() {
  final now = DateTime(2026, 10, 7, 10);

  Future<double> gap(WidgetTester tester, double statusBar) async {
    tester.view.physicalSize = const Size(393 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = FakeTasksApi(today: now);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.only(top: statusBar, bottom: 20),
            viewPadding: EdgeInsets.only(top: statusBar, bottom: 20),
          ),
          child: child!,
        ),
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
    await tester.tap(find.text('tasko-web'));
    await tester.pumpAndSettle();
    final toolbar = tester.getRect(find.textContaining(' open').first);
    final group = tester.getRect(find.text('OVERDUE').first);
    return group.top - toolbar.bottom;
  }

  testWidgets('the status bar inset does not push the list down', (
    tester,
  ) async {
    final plain = await gap(tester, 0);
    final withStatusBar = await gap(tester, 40);
    expect(withStatusBar, plain);
  });
}
