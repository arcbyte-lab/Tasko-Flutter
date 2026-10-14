import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/members_cubit.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';
import 'package:tasko/tasks/widgets/pickers.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);
  const web = FakeTasksApi.taskoWeb; // Mira owns it
  const app = FakeTasksApi.taskoApp; // Mira is a plain member

  group('MembersCubit', () {
    late FakeTasksApi api;
    late MembersCubit cubit;
    setUp(() async {
      api = FakeTasksApi(today: now);
      cubit = MembersCubit(api, web);
      await cubit.load();
    });

    String? roleOf(int id) =>
        cubit.state!.where((m) => m.user.id == id).firstOrNull?.role;

    test('add, change a role, remove', () async {
      final gita = (await cubit.search('gita')).single;
      await cubit.add(gita);
      expect(roleOf(gita.id), 'member');

      final budi = cubit.state!.firstWhere((m) => m.user.id == 3);
      await cubit.setRole(budi, 'viewer');
      expect(roleOf(3), 'viewer');

      await cubit.remove(cubit.state!.firstWhere((m) => m.user.id == 3));
      expect(roleOf(3), isNull);
    });

    test('leaving takes the project off the viewer’s tabs', () async {
      final home = HomeCubit(api, now: () => now);
      await home.load();
      await home.selectTab(app);

      final mira = (await api.membersOf(app)).first;
      await MembersCubit(api, app).remove(mira);
      await home.reloadTabs();

      expect(home.state.tabs, isNot(contains(app)));
      expect(home.state.activeTab, TaskTab.private);
    });
  });

  group('members screen', () {
    Future<void> openOn(WidgetTester tester, String tab) async {
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
      expect(find.byTooltip('Members'), findsNothing); // private tab
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Members'));
      await tester.pumpAndSettle();
    }

    testWidgets('an owner adds someone from the user search', (tester) async {
      await openOn(tester, 'tasko-web');
      expect(find.text('Gita'), findsNothing);

      await tester.tap(find.text('add member'));
      await tester.pumpAndSettle();
      Finder inPicker(String text) => find.descendant(
        of: find.byType(UserSearchPicker),
        matching: find.text(text),
      );
      expect(inPicker('Budi'), findsNothing); // already a member
      await tester.tap(inPicker('Gita'));
      await tester.pump();
      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();

      expect(find.text('Gita'), findsOneWidget);
    });

    testWidgets('a plain member sees no add, and a menu only on their row', (
      tester,
    ) async {
      await openOn(tester, 'tasko-app');
      expect(find.text('add member'), findsNothing);
      expect(find.byTooltip('Member options'), findsOneWidget);

      await tester.tap(find.byTooltip('Member options'));
      await tester.pumpAndSettle();
      expect(find.text('make viewer'), findsNothing);
      await tester.tap(find.text('leave project'));
      await tester.pumpAndSettle();

      // Back home, and the project's tab is gone.
      expect(find.text('add member'), findsNothing);
      expect(find.text('tasko-app'), findsNothing);
      expect(find.text('tasko-web'), findsOneWidget);
    });
  });
}
