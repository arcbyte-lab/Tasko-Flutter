import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/task_rules.dart';

Task task(
  TaskStatus status, {
  int id = 1,
  DateTime? due,
  String? proof,
  bool personal = false,
  int? assignee,
}) => Task(
  id: id,
  name: 't$id',
  status: status,
  dueDate: due,
  requiredProofType: proof,
  personal: personal,
  assigneeId: assignee,
);

void main() {
  // Wed Oct 7 2026, late evening, so date-only maths is exercised.
  final now = DateTime(2026, 10, 7, 23, 59);

  test('open means waiting, in progress or to do', () {
    expect(TaskStatus.values.where((s) => isOpen(task(s))), [
      TaskStatus.todo,
      TaskStatus.waiting,
      TaskStatus.inProgress,
    ]);
  });

  test('overdue ignores the time and needs an open task', () {
    final yesterdayLate = DateTime(2026, 10, 6, 23, 59);
    final todayEarly = DateTime(2026, 10, 7, 0, 1);
    expect(isOverdue(task(TaskStatus.waiting, due: yesterdayLate), now), true);
    expect(isOverdue(task(TaskStatus.waiting, due: todayEarly), now), false);
    expect(isOverdue(task(TaskStatus.review, due: yesterdayLate), now), false);
    expect(isOverdue(task(TaskStatus.waiting), now), false);
  });

  test('order: by due date, no date last, ties by id', () {
    final a = task(TaskStatus.waiting, id: 3, due: DateTime(2026, 10, 9));
    final b = task(TaskStatus.waiting, id: 1, due: DateTime(2026, 10, 9));
    final c = task(TaskStatus.waiting, id: 2, due: DateTime(2026, 10, 8));
    final d = task(TaskStatus.waiting, id: 0);
    expect(([a, b, c, d]..sort(taskOrder)).map((t) => t.id), [2, 1, 3, 0]);
  });

  test('day groups', () {
    DayGroup g(int offset, [TaskStatus s = TaskStatus.waiting]) =>
        dayGroup(task(s, due: DateTime(2026, 10, 7 + offset, 9)), now);
    expect(g(-1), DayGroup.overdue);
    expect(g(-1, TaskStatus.review), DayGroup.today);
    expect(g(0), DayGroup.today);
    expect(g(1), DayGroup.tomorrow);
    expect(g(2), DayGroup.later);
    expect(dayGroup(task(TaskStatus.waiting), now), DayGroup.noDate);
  });

  test('due counts: open tasks only, this month only', () {
    final counts = dueCounts([
      task(TaskStatus.waiting, due: DateTime(2026, 10, 14, 8)),
      task(TaskStatus.inProgress, due: DateTime(2026, 10, 14, 20)),
      task(TaskStatus.review, due: DateTime(2026, 10, 14)),
      task(TaskStatus.done, due: DateTime(2026, 10, 14)),
      task(TaskStatus.waiting, due: DateTime(2026, 11, 14)),
      task(TaskStatus.waiting),
    ], DateTime(2026, 10));
    expect(counts, {14: 2});
  });

  test('due by day: open tasks in order, same days as the counts', () {
    final tasks = [
      task(TaskStatus.waiting, id: 3, due: DateTime(2026, 10, 14, 20)),
      task(TaskStatus.inProgress, id: 2, due: DateTime(2026, 10, 14, 8)),
      task(TaskStatus.done, id: 4, due: DateTime(2026, 10, 14)),
      task(TaskStatus.waiting, id: 5, due: DateTime(2026, 10, 2)),
      task(TaskStatus.waiting, id: 6, due: DateTime(2026, 9, 30)),
    ];
    final days = dueByDay(tasks, DateTime(2026, 10));
    expect(days.map((d, l) => MapEntry(d, [for (final t in l) t.id])), {
      14: [2, 3],
      2: [5],
    });
    expect(dueCounts(tasks, DateTime(2026, 10)), {14: 2, 2: 1});
  });

  test('dots: 0, 1, 2 for 2-3, 3 for 4 or more (0016)', () {
    expect(
      [
        for (final n in [0, 1, 2, 3, 4, 9]) dotCount(n),
      ],
      [0, 1, 2, 2, 3, 3],
    );
  });

  test(
    'a day ring has one arc per kind of task due, in a fixed order (H12)',
    () {
      Task t(TaskStatus status) => Task(id: 1, name: 'x', status: status);
      final today = DateTime(2026, 10, 7);
      final past = DateTime(2026, 10, 3);
      final later = DateTime(2026, 10, 14);
      expect(dayMarks([], later, today), isEmpty);
      expect(dayMarks([t(TaskStatus.waiting)], later, today), {DayMark.open});
      // an open task before today is overdue, a task in review never is
      expect(dayMarks([t(TaskStatus.inProgress)], past, today), {
        DayMark.overdue,
      });
      expect(dayMarks([t(TaskStatus.review)], past, today), {DayMark.review});
      expect(dayMarks([t(TaskStatus.done)], past, today), {DayMark.done});
      // two of one kind are one arc
      expect(
        dayMarks(
          [t(TaskStatus.waiting), t(TaskStatus.inProgress), t(TaskStatus.done)],
          later,
          today,
        ),
        {DayMark.open, DayMark.done},
      );
      expect(DayMark.values, [
        DayMark.overdue,
        DayMark.open,
        DayMark.review,
        DayMark.done,
      ]);
    },
  );

  test('my tasks: who reviews, and what is mine (0004, 0017)', () {
    const lead = TaskTab(TabKind.division, 1, 'tech', role: 'supervisor');
    const member = TaskTab(TabKind.division, 1, 'tech', role: 'member');
    const pic = TaskTab(TabKind.project, 2, 'web', role: 'person-in-charge');
    expect([lead, member, pic, TaskTab.private].map(canReview), [
      true,
      false,
      true,
      false,
    ]);

    final mine = task(TaskStatus.waiting, assignee: 7);
    final theirs = task(TaskStatus.waiting, assignee: 8);
    final unassigned = task(TaskStatus.waiting);
    final theirReview = task(TaskStatus.review, assignee: 8);
    final personal = task(TaskStatus.todo, personal: true);
    expect(isMine(mine, member, 7), isTrue);
    expect(isMine(theirs, member, 7), isFalse);
    expect(isMine(unassigned, lead, 7), isFalse);
    expect(isMine(theirReview, lead, 7), isTrue);
    expect(isMine(theirReview, member, 7), isFalse);
    expect(isMine(personal, TaskTab.private, 7), isTrue);
    expect(isOpenOrReview(theirReview), isTrue);
    expect(isOpenOrReview(task(TaskStatus.done)), isFalse);
  });

  test('monday of the week, across a month end', () {
    expect(mondayOf(DateTime(2026, 10, 7, 23, 59)), DateTime(2026, 10, 5));
    expect(mondayOf(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
    expect(mondayOf(DateTime(2026, 10, 26)), DateTime(2026, 10, 26));
  });

  group('status after a tick', () {
    test('team task without proof: done, and back to waiting', () {
      expect(statusAfterTick(task(TaskStatus.waiting)), TaskStatus.done);
      expect(statusAfterTick(task(TaskStatus.inProgress)), TaskStatus.done);
      expect(statusAfterTick(task(TaskStatus.done)), TaskStatus.waiting);
    });

    test('personal task: done, and back to to do', () {
      expect(
        statusAfterTick(task(TaskStatus.todo, personal: true)),
        TaskStatus.done,
      );
      expect(
        statusAfterTick(task(TaskStatus.done, personal: true)),
        TaskStatus.todo,
      );
    });

    test('in review: nothing', () {
      expect(statusAfterTick(task(TaskStatus.review)), isNull);
    });

    test('proof required: asks for the proof first', () {
      expect(
        () => statusAfterTick(task(TaskStatus.waiting, proof: 'image')),
        throwsA(isA<ProofRequired>()),
      );
    });

    test('proof required, with a link: review', () {
      expect(
        statusAfterTick(
          task(TaskStatus.waiting, proof: 'image'),
          proofUrl: 'https://example.com/shot.png',
        ),
        TaskStatus.review,
      );
    });
  });

  test('short date', () {
    expect(shortDate(DateTime(2026, 10, 3), now), 'Oct 3');
    expect(shortDate(DateTime(2027, 1, 3), now), 'Jan 3, 2027');
  });

  group('action bar', () {
    DetailAction a(Task t, {bool reviewer = false}) =>
        actionFor(t, viewerId: 1, canReview: reviewer);
    final (me, other) = (1, 2);

    test('the assignee starts, finishes, or submits proof', () {
      expect(
        a(task(TaskStatus.waiting, assignee: me)),
        DetailAction.startWorking,
      );
      expect(
        a(task(TaskStatus.inProgress, assignee: me)),
        DetailAction.markDone,
      );
      expect(
        a(task(TaskStatus.inProgress, assignee: me, proof: 'image')),
        DetailAction.submitProof,
      );
      expect(
        a(task(TaskStatus.review, assignee: me)),
        DetailAction.waitingForReview,
      );
    });

    test('a reviewer reviews, even their own task', () {
      expect(
        a(task(TaskStatus.review, assignee: other), reviewer: true),
        DetailAction.review,
      );
      expect(
        a(task(TaskStatus.review, assignee: me), reviewer: true),
        DetailAction.review,
      );
    });

    test('someone else sees no bar until done', () {
      expect(a(task(TaskStatus.waiting, assignee: other)), DetailAction.none);
      expect(a(task(TaskStatus.review, assignee: other)), DetailAction.none);
      expect(a(task(TaskStatus.done, assignee: other)), DetailAction.done);
    });

    test('personal tasks are always mine', () {
      expect(
        a(task(TaskStatus.todo, personal: true)),
        DetailAction.startWorking,
      );
      expect(
        a(task(TaskStatus.inProgress, personal: true)),
        DetailAction.markDone,
      );
    });
  });

  test('relative time', () {
    expect(
      relativeTime(now.subtract(const Duration(seconds: 20)), now),
      'just now',
    );
    expect(
      relativeTime(now.subtract(const Duration(minutes: 45)), now),
      '45m ago',
    );
    expect(relativeTime(now.subtract(const Duration(hours: 2)), now), '2h ago');
    expect(relativeTime(now.subtract(const Duration(days: 3)), now), '3d ago');
    expect(relativeTime(DateTime(2026, 9, 1), now), 'Sep 1');
  });

  test('repeat summary', () {
    expect(repeatSummary(const Repeat(unit: RepeatUnit.day), now), 'every day');
    expect(
      repeatSummary(const Repeat(every: 2, weekdays: [1, 3, 5]), now),
      'every 2 weeks on Mon, Wed and Fri',
    );
    expect(
      repeatSummary(const Repeat(unit: RepeatUnit.month, count: 6), now),
      'every month, 6 times',
    );
    expect(
      repeatSummary(
        Repeat(unit: RepeatUnit.year, until: DateTime(2030, 1, 1)),
        now,
      ),
      'every year, until Jan 1, 2030',
    );
  });

  test('notification time', () {
    final at = DateTime(2026, 10, 7, 10);
    expect(notificationTime(DateTime(2026, 10, 7, 9, 55), at), '5m ago');
    expect(notificationTime(DateTime(2026, 10, 7, 0, 30), at), '9h ago');
    expect(notificationTime(DateTime(2026, 10, 6, 23), at), 'yesterday');
    expect(notificationTime(DateTime(2026, 10, 5, 12), at), 'Oct 5');
  });

  test('who can create projects and manage members (0010)', () {
    TaskTab tab(TabKind kind, String? role) =>
        TaskTab(kind, 1, 'x', role: role);
    expect(canCreateProject(tab(TabKind.division, 'admin')), isTrue);
    expect(canCreateProject(tab(TabKind.division, 'supervisor')), isTrue);
    expect(canCreateProject(tab(TabKind.division, 'member')), isFalse);
    expect(canCreateProject(tab(TabKind.project, 'owner')), isFalse);
    expect(canManageMembers(tab(TabKind.project, 'owner')), isTrue);
    expect(canManageMembers(tab(TabKind.project, 'person-in-charge')), isTrue);
    expect(canManageMembers(tab(TabKind.project, 'member')), isFalse);
    expect(canManageMembers(tab(TabKind.division, 'admin')), isFalse);
    expect(canManageMembers(TaskTab.private), isFalse);
  });

  test('who can set up repeats (0012)', () {
    TaskTab tab(TabKind kind, String? role) =>
        TaskTab(kind, 1, 'x', role: role);
    expect(canManageRepeats(tab(TabKind.division, 'admin')), isTrue);
    expect(canManageRepeats(tab(TabKind.division, 'supervisor')), isTrue);
    expect(canManageRepeats(tab(TabKind.division, 'member')), isFalse);
    expect(canManageRepeats(tab(TabKind.project, 'owner')), isFalse);
    expect(canManageRepeats(TaskTab.private), isFalse);
  });

  group('workload (the home strip)', () {
    const me = 1;
    const web = TaskTab(TabKind.project, 2, 'web', role: 'member');
    final today = DateTime(2026, 10, 7);
    Task t(
      TaskStatus s, {
      int id = 1,
      DateTime? due,
      int? assignee = me,
      int? creator,
      bool personal = false,
    }) => Task(
      id: id,
      name: 't$id',
      status: s,
      dueDate: due,
      assigneeId: assignee,
      creatorId: creator,
      personal: personal,
    );
    Workload count(List<(Task, TaskTab)> all) => countWorkload(all, me, today);

    test('in progress: mine and started, personal included', () {
      final w = count([
        (t(TaskStatus.inProgress), web),
        (t(TaskStatus.inProgress, id: 2, assignee: 9), web),
        (
          t(TaskStatus.inProgress, id: 3, assignee: null, personal: true),
          TaskTab.private,
        ),
        (t(TaskStatus.waiting, id: 4), web),
      ]);
      expect(w.inProgress, 2);
    });

    test('to review: made by me, assigned to someone else', () {
      final w = count([
        (t(TaskStatus.review, assignee: 9, creator: me), web),
        (t(TaskStatus.review, id: 2, assignee: me, creator: me), web),
        (t(TaskStatus.review, id: 3, assignee: 9, creator: 5), web),
      ]);
      expect(w.toReview, 1);
    });

    test('due soon is today or tomorrow; overdue is before today', () {
      final w = count([
        (t(TaskStatus.waiting, due: DateTime(2026, 10, 6)), web),
        (t(TaskStatus.waiting, id: 2, due: DateTime(2026, 10, 7, 23)), web),
        (t(TaskStatus.waiting, id: 3, due: DateTime(2026, 10, 8)), web),
        (t(TaskStatus.waiting, id: 4, due: DateTime(2026, 10, 9)), web),
        (t(TaskStatus.done, id: 5, due: DateTime(2026, 10, 1)), web),
      ]);
      expect((w.overdue, w.dueSoon), (1, 2));
    });

    test('a task can count twice', () {
      final w = count([
        (t(TaskStatus.inProgress, due: DateTime(2026, 10, 1)), web),
      ]);
      expect((w.inProgress, w.overdue), (1, 1));
    });
  });
}
