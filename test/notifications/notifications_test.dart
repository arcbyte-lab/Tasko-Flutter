import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/notifications/notifications_cubit.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);

  group('cubit', () {
    late NotificationsCubit cubit;
    setUp(() async {
      cubit = NotificationsCubit(FakeTasksApi(today: now));
      await cubit.load();
    });

    test('newest first, three unread', () {
      final list = cubit.state!;
      expect(list, hasLength(7));
      expect(list.first.text, 'Ana assigned you Deploy staging');
      expect(list.where((n) => n.unread), hasLength(3));
    });

    test('mark one, then all, read', () async {
      await cubit.markRead(cubit.state!.first);
      expect(cubit.state!.where((n) => n.unread), hasLength(2));
      await cubit.markAllRead();
      expect(cubit.state!.where((n) => n.unread), isEmpty);
    });
  });

  testWidgets('the bell opens notifications; going back clears the dot', (
    tester,
  ) async {
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

    await tester.tap(find.byTooltip('Notifications, unread'));
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.text('Budi commented on Review PR #42'), findsOneWidget);

    await tester.tap(find.text('mark all read'));
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsNothing);
    final markAll = find.widgetWithText(TextButton, 'mark all read');
    expect(tester.widget<TextButton>(markAll).onPressed, isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Notifications, unread'), findsNothing);
  });
}
