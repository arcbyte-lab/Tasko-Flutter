import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/core/theme/app_palette.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/widgets/task_row.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);
  const mira = User(id: 1, name: 'Mira');
  const ana = User(id: 2, name: 'Ana');

  Task task({
    TaskStatus status = TaskStatus.inProgress,
    Priority priority = Priority.urgent,
    DateTime? due,
    String? code = 'TW-0042',
  }) => Task(
    id: 1,
    name: 'Fix login redirect',
    status: status,
    priority: priority,
    dueDate: due,
    code: code,
  );

  Future<void> pump(
    WidgetTester tester,
    TaskRow row, {
    AppPalette palette = AppPalette.light,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: PaletteScope(palette: palette, child: row),
        ),
      ),
    ),
  );

  Color? fillOf(WidgetTester tester, Finder f) =>
      (tester.widget<Container>(f).decoration as BoxDecoration).color;

  testWidgets('the row of hifi H1: avatar, title and date, code and badges', (
    tester,
  ) async {
    await pump(
      tester,
      TaskRow(
        task: task(due: DateTime(2026, 10, 3)),
        now: now,
        onTap: () {},
        assignee: mira,
        mine: true,
      ),
    );
    expect(find.text('M'), findsOneWidget);
    expect(find.text('Fix login redirect'), findsOneWidget);
    expect(find.text('Overdue Oct 3'), findsOneWidget);
    expect(find.text('TW-0042'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    // no checkbox: ticking is in Task Detail
    expect(find.byType(InkResponse), findsNothing);
    expect(tester.getSize(find.byType(TaskRow)).height, 62);
  });

  testWidgets(
    'the avatar: blue for the viewer, light for others, grey for nobody',
    (tester) async {
      Finder avatar() => find.descendant(
        of: find.byType(TaskAvatar),
        matching: find.byType(Container),
      );
      await pump(
        tester,
        TaskRow(
          task: task(),
          now: now,
          onTap: () {},
          assignee: mira,
          mine: true,
        ),
      );
      expect(fillOf(tester, avatar()), const Color(0xFF2563EB));
      await pump(
        tester,
        TaskRow(task: task(), now: now, onTap: () {}, assignee: ana),
      );
      expect(find.text('A'), findsOneWidget);
      expect(fillOf(tester, avatar()), const Color(0xFFE0F2FE));
      await pump(tester, TaskRow(task: task(), now: now, onTap: () {}));
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    },
  );

  testWidgets(
    'the scope follows the code with no spaces; no date, no code, no problem',
    (tester) async {
      await pump(
        tester,
        TaskRow(
          task: task(due: DateTime(2026, 10, 9), code: null),
          now: now,
          onTap: () {},
          tabName: 'tasko-web',
        ),
      );
      // no code: the scope alone
      expect(find.text('Oct 9'), findsOneWidget);
      expect(find.text('tasko-web'), findsOneWidget);
      expect(find.text('TW-0042'), findsNothing);
      await pump(
        tester,
        TaskRow(task: task(), now: now, onTap: () {}, tabName: 'tech'),
      );
      expect(find.text('TW-0042·tech'), findsOneWidget);
      await pump(tester, TaskRow(task: task(), now: now, onTap: () {}));
      expect(find.textContaining('Oct'), findsNothing);
    },
  );

  testWidgets('the status badge ends on the right edge, under the date', (
    tester,
  ) async {
    // The code is short, so a Flexible beside a Spacer once left a gap here.
    for (final code in ['TW-1', 'TECH-0141']) {
      await pump(
        tester,
        TaskRow(
          task: task(due: DateTime(2026, 10, 9), code: code),
          now: now,
          onTap: () {},
          tabName: 'tech',
        ),
      );
      Rect edge(String text) => tester.getRect(find.text(text));
      Rect badge() => tester.getRect(
        find.ancestor(
          of: find.text('In Progress'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border?.isUniform == true,
          ),
        ),
      );
      expect(badge().right, edge('Oct 9').right);
    }
  });

  testWidgets('badge colours follow the pen file, light and dark', (
    tester,
  ) async {
    Finder badge(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border?.isUniform == true,
      ),
    );
    await pump(
      tester,
      TaskRow(
        task: task(status: TaskStatus.review, priority: Priority.medium),
        now: now,
        onTap: () {},
      ),
    );
    expect(fillOf(tester, badge('Medium')), const Color(0x80FFFBEB));
    expect(fillOf(tester, badge('Under Review')), const Color(0x80FFF7ED));
    await pump(
      tester,
      TaskRow(
        task: task(status: TaskStatus.review, priority: Priority.medium),
        now: now,
        onTap: () {},
      ),
      palette: AppPalette.dark,
    );
    expect(fillOf(tester, badge('Medium')), const Color(0x26F59E0B));
    expect(fillOf(tester, badge('Under Review')), const Color(0x26F97316));
  });

  testWidgets('a done row has a grey title and a Done badge', (tester) async {
    await pump(
      tester,
      TaskRow(
        task: task(status: TaskStatus.done),
        now: now,
        onTap: () {},
      ),
    );
    expect(find.text('Done'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Fix login redirect'));
    expect(title.style?.color, AppPalette.light.muted);
    expect(title.style?.decoration, isNull);
  });
}
