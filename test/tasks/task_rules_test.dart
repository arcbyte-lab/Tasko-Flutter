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

  test('notification time', () {
    final at = DateTime(2026, 10, 7, 10);
    expect(notificationTime(DateTime(2026, 10, 7, 9, 55), at), '5m ago');
    expect(notificationTime(DateTime(2026, 10, 7, 0, 30), at), '9h ago');
    expect(notificationTime(DateTime(2026, 10, 6, 23), at), 'yesterday');
    expect(notificationTime(DateTime(2026, 10, 5, 12), at), 'Oct 5');
  });
}
