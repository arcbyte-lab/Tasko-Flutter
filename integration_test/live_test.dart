import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tasko/main.dart' as app;
import 'package:tasko/tasks/http_tasks_api.dart';
import 'package:tasko/tasks/widgets/pickers.dart';
import 'package:tasko/tasks/widgets/task_row.dart';

/// Manual smoke test: drives the real app on a phone against the live
/// Tasko-API and its seed data (Tasko-API's seed.sql + cases.sql). CI does
/// not run it (`flutter test` reads only test/).
///
///   flutter test integration_test/live_test.dart -d DEVICE_ID
///
/// It ticks, reviews and comments on live tasks, so start from a fresh seed
/// and reseed after every run, from Tasko-API:
///
///   npx wrangler d1 execute DB --remote --file seed/seed.sql -y
///   npx wrangler d1 execute DB --remote --file seed/cases.sql -y
///
/// Or against a local Tasko-API, leaving the live data alone. From
/// Tasko-API, seed the local D1 the same way (`--local` for `--remote`),
/// then `npx wrangler dev --local --port 8787`; over USB,
/// `adb reverse tcp:8787 tcp:8787`; and add
/// `--dart-define=API_URL=http://localhost:8787` to the command above.
///
/// A refused change (409, 422) can't be checked here: the harness fails the
/// test on the unhandled error before the app's toast handler sees it. Try
/// one by hand, e.g. a second extension request on "Document VPN setup".
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final results = <String>[];

  testWidgets('live walkthrough', (tester) async {
    /// Pumps until [finder] shows (or, with [gone], stops showing), for real
    /// network round trips.
    Future<void> waitFor(
      Finder finder, {
      int seconds = 20,
      bool gone = false,
    }) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (finder.evaluate().isNotEmpty != gone) return;
      }
      throw TestFailure('timed out waiting for $finder${gone ? ' to go' : ''}');
    }

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();
    }

    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
        results.add('PASS $name');
      } catch (e) {
        results.add('FAIL $name: ${e.toString().split('\n').first}');
        // Back to home for the next step: close any sheet or page.
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.popUntil((r) => r.isFirst);
        await settle();
      }
      // ignore: avoid_print
      print(results.last);
    }

    Future<void> logIn(String email) async {
      await tester.enterText(find.byType(TextField).at(0), email);
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.tap(find.text('log in'));
      await settle();
    }

    Future<void> logOut() async {
      await tester.tap(find.byTooltip('Account'));
      await settle();
      await tester.tap(find.text('log out'));
      await waitFor(find.text('log in'));
      await settle();
    }

    Future<void> openTab(String name) async {
      final tab = find.text(name).first;
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await settle();
    }

    Finder list() => find
        .descendant(
          of: find.byType(ListView).hitTestable(),
          matching: find.byType(Scrollable),
        )
        .first;

    Future<void> scrollTo(Finder f) async {
      await tester.drag(list(), const Offset(0, 3000));
      await settle();
      await tester.scrollUntilVisible(f, 150, scrollable: list());
      await settle();
    }

    Future<void> openTask(String tab, String name) async {
      await openTab(tab);
      await scrollTo(find.text(name));
      await tester.tap(find.text(name));
      await waitFor(find.text('priority'));
      await settle();
    }

    Future<void> closeSheet() async {
      await tester.tapAt(const Offset(200, 30)); // the scrim
      await settle();
    }

    Finder button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

    // Start logged out: a token left from before a reseed is a 401, which
    // the harness would count as a failure.
    await const FlutterSecureStorage().deleteAll();
    app.main();
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.text('log in').evaluate().isNotEmpty ||
          find.byTooltip('Account').evaluate().isNotEmpty) {
        break;
      }
    }
    await settle();
    if (find.byTooltip('Account').evaluate().isNotEmpty) await logOut();

    await step('wrong password shows the server message', () async {
      await tester.enterText(find.byType(TextField).at(0), 'mira@arcbyte.dev');
      await tester.enterText(find.byType(TextField).at(1), 'nope');
      await tester.tap(find.text('log in'));
      await waitFor(find.text('Invalid email or password'));
    });

    await step('Mira logs in and sees her eight tabs', () async {
      await logIn('mira@arcbyte.dev');
      await waitFor(find.text('welcome, Mira'));
      for (final t in [
        'private',
        'tech',
        'ops',
        'tasko-app',
        'tasko-web',
        'ops-site',
        'ops-wiki',
        'contracts',
      ]) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      for (final t in ['legal', 'old', 'old-site', 'archived-app']) {
        expect(find.text(t), findsNothing, reason: t);
      }
    });

    await step('each tab loads its tasks', () async {
      for (final (tab, task) in [
        ('private', 'Call the bank'),
        ('tech', 'Renew SSL certificate'),
        ('ops', 'Restock printer paper'),
        ('tasko-web', 'Fix login redirect'),
        ('contracts', 'Review NDA template'),
      ]) {
        await openTab(tab);
        await scrollTo(find.text(task));
        expect(find.text(task), findsOneWidget, reason: tab);
      }
    });

    await step('ticking a plain task moves it to completed', () async {
      await openTab('tasko-app');
      await scrollTo(find.text('Draft API contract'));
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(TaskRow, 'Draft API contract'),
          matching: find.byType(InkResponse),
        ),
      );
      await settle();
      await scrollTo(find.textContaining('completed ('));
      expect(find.text('Draft API contract'), findsNothing);
    });

    await step('ticking a proof task asks for a link, then sends it', () async {
      await openTab('ops-site');
      await scrollTo(find.text('Survey the new site'));
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(TaskRow, 'Survey the new site'),
          matching: find.byType(InkResponse),
        ),
      );
      await waitFor(find.text('send for review'));
      await tester.enterText(
        find.byType(TextField).last,
        'https://photos.example.com/site-survey.jpg',
      );
      await tester.pump();
      await tester.tap(find.text('send for review'));
      await settle();
      expect(find.text('send for review'), findsNothing);
      await tester.tap(find.text('Survey the new site'));
      await waitFor(find.text('https://photos.example.com/site-survey.jpg'));
      expect(find.text('review'), findsWidgets);
      await closeSheet();
    });

    await step(
      'the latest proof shows; a reviewer rejects with a reason',
      () async {
        await openTask('ops-site', 'Install wifi');
        await waitFor(
          find.text('https://photos.example.com/wifi-second-try.jpg'),
        );
        expect(find.text('Hadi'), findsWidgets); // inactive assignee
        await tester.tap(button('reject'));
        await settle();
        await tester.enterText(find.byType(TextField).last, 'Still no router');
        await tester.pump();
        await tester.tap(button('reject').last);
        await settle();
        expect(find.text('in progress'), findsWidgets);
        await closeSheet();
      },
    );

    await step('a division supervisor approves', () async {
      await openTask('ops', 'Check fire extinguishers');
      await tester.tap(button('approve'));
      await settle();
      await waitFor(find.textContaining('done ·'));
      await closeSheet();
    });

    await step(
      'a member sees no review buttons where she does not review',
      () async {
        await openTask('ops-wiki', 'Write onboarding wiki');
        expect(find.text('approve'), findsNothing);
        await closeSheet();
      },
    );

    await step('comments: deleted hidden, new one appears', () async {
      await openTask('ops-site', 'Move furniture');
      await tester.scrollUntilVisible(
        find.text('DISCUSSION'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Deleted, so it never shows.'), findsNothing);
      expect(find.text('Comment from Hadi, now inactive.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'write a comment…'),
        'Device check',
      );
      await tester.tap(find.byTooltip('Send'));
      await waitFor(find.text('Device check'));
      await closeSheet();
    });

    await step('"start working" moves a task to in progress (0008)', () async {
      await openTask('tasko-app', 'Port theme tokens');
      await tester.tap(button('start working'));
      await waitFor(button('mark done'));
      expect(find.text('in progress'), findsWidgets);
      await closeSheet();
    });

    await step('create a personal task', () async {
      await openTab('private');
      await tester.tap(find.byTooltip('Create task'));
      await settle();
      await tester.enterText(find.byType(TextField).first, 'Device test task');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'done'));
      await settle();
      await scrollTo(find.text('Device test task'));
    });

    await step('notifications: "Someone", then mark all read', () async {
      await tester.tap(find.byTooltip('Notifications, unread'));
      await waitFor(find.text('Someone assigned you Review NDA template'));
      await tester.tap(find.text('mark all read'));
      await settle();
      await tester.pageBack();
      await settle();
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });

    // Projects and members (arcbyte decision 0010). Mira supervises ops.
    await step('a division lead creates a project', () async {
      await tester.ensureVisible(find.byTooltip('New project'));
      await tester.tap(find.byTooltip('New project'));
      await settle();
      expect(find.byTooltip('Division'), findsNothing); // ops is her only one
      await tester.enterText(find.byType(TextField).last, 'Device project');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'done'));
      await waitFor(find.byTooltip('Members'));
      expect(find.text('Device project'), findsWidgets);
    });

    await step('the owner adds Budi from the user search', () async {
      await tester.tap(find.byTooltip('Members'));
      await waitFor(find.text('add member'));
      await tester.tap(find.text('add member'));
      await settle();
      await tester.enterText(find.byType(TextField).last, 'budi');
      final budi = find.descendant(
        of: find.byType(UserSearchPicker),
        matching: find.text('Budi'),
      );
      await waitFor(budi);
      await tester.tap(budi);
      await tester.pump();
      await tester.tap(find.text('done'));
      await waitFor(find.text('Budi'));
    });

    await step('the owner makes Budi a viewer', () async {
      // The viewer's own row comes first, so Budi's menu is the last.
      await tester.tap(find.byTooltip('Member options').last);
      await settle();
      await tester.tap(find.text('make viewer'));
      await waitFor(find.text('viewer'));
      await tester.pageBack();
      await settle();
    });

    await step('a plain member leaves a project; its tab goes', () async {
      await openTab('tasko-app');
      await tester.tap(find.byTooltip('Members'));
      await waitFor(find.byTooltip('Member options'));
      expect(find.text('add member'), findsNothing);
      expect(find.byTooltip('Member options'), findsOneWidget); // her own row
      await tester.tap(find.byTooltip('Member options'));
      await settle();
      await tester.tap(find.text('leave project'));
      await waitFor(find.text('tasko-app'), gone: true);
      expect(find.text('tasko-web'), findsWidgets);
    });

    await step('log out returns to login', logOut);

    await step('Budi sees the project and why', () async {
      await logIn('budi@arcbyte.dev');
      await waitFor(find.text('Device project'));
      await tester.tap(find.byTooltip('Notifications, unread'));
      await waitFor(find.text('Mira added you to Device project'));
      await tester.pageBack();
      await settle();
    });

    await step('a project he is added to meanwhile shows after '
        'notifications', () async {
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is IconButton && (w.tooltip ?? '').startsWith('Notifications'),
        ),
      );
      await settle();
      // Mira, from elsewhere, while Budi reads his notifications.
      final (token, _) = await login('mira@arcbyte.dev', 'password');
      final mira = HttpTasksApi(token);
      await mira.addMember(await mira.createProject(2, 'Second project'), 3);
      await tester.pageBack();
      await waitFor(find.text('Second project'));
      await logOut();
    });

    // Repeating tasks (arcbyte decision 0012). Ana is tech's admin; Mira is
    // a plain member there.
    await step('a division lead sets up a repeat', () async {
      await logIn('ana@arcbyte.dev');
      await waitFor(find.text('welcome, Ana'));
      await openTask('tech', 'Renew SSL certificate');
      await tester.tap(find.text('repeat'));
      // A new rule: the screen has no "stop repeating" yet.
      await waitFor(find.widgetWithText(TextButton, 'done'));
      await tester.tap(find.widgetWithText(TextButton, 'done'));
      // The Repeat screen's own summary says "every week" too: wait for it
      // to go, so the next tap lands on the sheet's scrim.
      await waitFor(find.widgetWithText(TextButton, 'done'), gone: true);
      await waitFor(find.textContaining('every week'));
      await settle();
      await closeSheet();
    });

    await step(
      'the repeat icon opens the repeating view and its history',
      () async {
        // Only once the detail sheet has gone can the icon take the tap.
        final icon = find.byTooltip('Repeating').hitTestable();
        await waitFor(icon);
        await tester.tap(icon);
        await waitFor(find.text('tech repeating'));
        await waitFor(find.text('Renew SSL certificate').last);
        await tester.tap(find.text('Renew SSL certificate').last);
        await waitFor(find.text('OCCURRENCES'));
        expect(
          find.textContaining('creates a new task every week'),
          findsWidgets,
        );
        expect(find.text('waiting'), findsWidgets);
        // Two pages deep: pageBack would see two back buttons mid-transition.
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .popUntil((r) => r.isFirst);
        await settle();
        await logOut();
      },
    );

    await step('a member sees no repeat icon and a read-only rule', () async {
      await logIn('mira@arcbyte.dev');
      await waitFor(find.text('welcome, Mira'));
      await openTab('tech');
      expect(find.byTooltip('Repeating'), findsNothing);
      await openTask('tech', 'Renew SSL certificate');
      expect(find.textContaining('every week'), findsOneWidget);
      await tester.tap(find.text('repeat'));
      await settle();
      expect(find.text('stop repeating'), findsNothing);
      await closeSheet();
      await logOut();
    });

    // Activity logs (arcbyte decision 0014). Ana's repeat above is a
    // `repeat.set` row in tech's log.
    Future<void> home() async {
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .popUntil((r) => r.isFirst);
      await settle();
    }

    await step('a lead opens the division log, then a task from it', () async {
      await logIn('ana@arcbyte.dev');
      await waitFor(find.text('welcome, Ana'));
      await openTab('tech');
      final icon = find.byTooltip('Activity').hitTestable();
      await waitFor(icon);
      await tester.tap(icon);
      await waitFor(find.text('tech activity'));
      final row = find.textContaining('Ana made Renew SSL certificate repeat');
      await waitFor(row);
      await tester.tap(row.first);
      await waitFor(find.text('priority'));
      await home();
    });

    await step('the task log, from Task Detail’s menu', () async {
      await openTask('tech', 'Renew SSL certificate');
      await tester.tap(find.byTooltip('More'));
      await settle();
      await tester.tap(find.text('activity'));
      await waitFor(find.text('Renew SSL certificate activity'));
      await waitFor(find.textContaining('Ana made it repeat'));
      await home();
    });

    await step('the assignee picker opens in Task Detail', () async {
      await openTask('tech', 'Renew SSL certificate');
      await tester.tap(find.text('assignee'));
      await waitFor(find.text('Budi'));
      await home();
    });

    await step('my activity, and a member has no log icon', () async {
      await tester.tap(find.byTooltip('Account'));
      await settle();
      await tester.tap(find.text('my activity'));
      await waitFor(find.text('Ana activity'));
      await waitFor(find.textContaining('Ana made Renew SSL certificate'));
      await home();
      await logOut();
      await logIn('mira@arcbyte.dev');
      await waitFor(find.text('welcome, Mira'));
      await openTab('tech');
      expect(find.byTooltip('Activity'), findsNothing);
      await logOut();
    });

    await step('an inactive user cannot log in', () async {
      await logIn('hadi@arcbyte.dev');
      await waitFor(find.text('Invalid email or password'));
    });

    await step('a user with no team sees only private', () async {
      await logIn('indah@arcbyte.dev');
      await waitFor(find.text('Ask HR which team I join'));
      expect(find.text('tech'), findsNothing);
      await logOut();
    });

    // ignore: avoid_print
    print('RESULTS\n${results.join('\n')}');
    expect(results.where((r) => r.startsWith('FAIL')), isEmpty);
  });
}
