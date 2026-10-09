import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tasko/main.dart' as app;
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
/// A refused change (409, 422) can't be checked here: the harness fails the
/// test on the unhandled error before the app's toast handler sees it. Try
/// one by hand, e.g. a second extension request on "Document VPN setup".
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final results = <String>[];

  testWidgets('live walkthrough', (tester) async {
    /// Pumps until [finder] shows, for real network round trips.
    Future<void> waitFor(Finder finder, {int seconds = 20}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (finder.evaluate().isNotEmpty) return;
      }
      throw TestFailure('timed out waiting for $finder');
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

    await step('log out returns to login', logOut);

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
