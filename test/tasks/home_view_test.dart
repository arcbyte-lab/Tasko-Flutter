import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_theme.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/screens/home_panel.dart';
import 'package:tasko/tasks/tasks_api.dart';
import 'package:tasko/tasks/widgets/tab_strip.dart';
import 'package:tasko/tasks/widgets/task_row.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);
  var loggedOut = false;

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
            child: HomePanel(onLogOut: () => loggedOut = true),
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

  testWidgets('ticking moves a task to completed; a proof task asks a link', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(await checkboxOf(tester, 'Deploy staging'));
    await tester.pumpAndSettle();
    expect(find.text('Deploy staging'), findsNothing);
    await scrollTo(tester, find.text('completed (4)'));

    await tester.tap(await checkboxOf(tester, 'Upload release screenshots'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'https://x.dev/a.png');
    await tester.pump();
    await tester.tap(find.text('send for review'));
    await tester.pumpAndSettle();
    expect(find.text('send for review'), findsNothing);
    expect(find.text('Upload release screenshots'), findsOneWidget);
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
    expect(loggedOut, isTrue);
  });

  group('swiping the list', () {
    Future<void> fling(WidgetTester tester, double dx) async {
      await tester.fling(find.byType(ListView), Offset(dx, 0), 1000);
      await tester.pumpAndSettle();
    }

    Future<void> startOn(WidgetTester tester, String tab) =>
        pump(tester, tab: tab);

    testWidgets('left opens the next tab, right the previous', (tester) async {
      await startOn(tester, 'tech');
      await fling(tester, -300);
      expect(find.text('Set up CI'), findsOneWidget); // tasko-app
      await fling(tester, 300);
      expect(find.text('no tasks here'), findsOneWidget); // tech again
    });

    testWidgets('stops at both ends', (tester) async {
      await startOn(tester, 'private');
      await fling(tester, 300);
      expect(find.text('Renew passport'), findsOneWidget);

      await fling(tester, -300); // tech
      await fling(tester, -300); // tasko-app
      await fling(tester, -300); // tasko-web, the last
      await fling(tester, -300);
      expect(find.text('Fix login redirect'), findsOneWidget);
    });

    testWidgets('the toolbar stays put while the list slides', (tester) async {
      await startOn(tester, 'tech');
      await tester.fling(find.byType(ListView), const Offset(-300, 0), 1000);
      await tester.pump(const Duration(milliseconds: 100)); // mid-slide
      expect(find.byType(ListView), findsNWidgets(2)); // both lists moving
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.byTooltip('View options'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byTooltip('Search'),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('the next tab follows the finger during a drag', (
      tester,
    ) async {
      await startOn(tester, 'tech');
      final g = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await g.moveBy(const Offset(-40, 0)); // past the drag slop
      await g.moveBy(const Offset(-100, 0));
      await tester.pump();
      expect(find.byType(ListView), findsNWidgets(2)); // tasko-app peeks in
      expect(find.text('Set up CI'), findsOneWidget);
      await g.up(); // a short, slow drag snaps back
      await tester.pumpAndSettle();
      expect(find.text('no tasks here'), findsOneWidget);
      expect(find.text('Set up CI'), findsNothing);
    });

    /// The tab strip's primary underline, as painted.
    Rect underline() {
      Rect? found;
      expect(
        find.byType(TabStrip),
        paints..something((method, args) {
          if (method != #drawRect) return false;
          // Compared as ARGB: Paint hands back a rebuilt, float-based Color.
          final color = (args[1] as Paint).color.toARGB32();
          if (color != AppColors.primary.toARGB32()) return false;
          found = args[0] as Rect;
          return true;
        }),
      );
      return found!;
    }

    testWidgets('the underline moves with the pages', (tester) async {
      await startOn(tester, 'tech');
      final atTech = underline(); // painted from the first frame on

      final g = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await g.moveBy(const Offset(-40, 0));
      await g.moveBy(const Offset(-60, 0));
      await tester.pump();
      final midway = underline();

      await g.moveBy(const Offset(-200, 0));
      await g.up();
      await tester.pumpAndSettle();
      final atApp = underline();

      expect(midway.left, greaterThan(atTech.left));
      expect(midway.left, lessThan(atApp.left));
      expect(midway.width, inExclusiveRange(atTech.width, atApp.width));
    });

    testWidgets('a slow drag does not switch', (tester) async {
      await startOn(tester, 'tech');
      await tester.drag(find.byType(ListView), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(find.text('no tasks here'), findsOneWidget);
    });
  });
}
