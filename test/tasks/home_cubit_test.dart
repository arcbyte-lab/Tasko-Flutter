import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/tasks/home_cubit.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/task_rules.dart';
import 'package:tasko/tasks/tasks_api.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);
  late HomeCubit cubit;

  setUp(() async {
    cubit = HomeCubit(FakeTasksApi(today: now), now: () => now);
    await cubit.load();
  });

  test('loads my tasks first in the list but home opens on tech; '
      'My Workspace opens on my tasks (0020)', () {
    expect(cubit.state.tabs.map((t) => t.name), [
      'my tasks',
      'private',
      'tech',
      'tasko-app',
      'tasko-web',
    ]);
    expect(cubit.state.activeTab, FakeTasksApi.tech);
    expect(cubit.state.homeTabs, [
      FakeTasksApi.tech,
      FakeTasksApi.taskoApp,
      FakeTasksApi.taskoWeb,
    ]);
    expect(cubit.state.workspaceTabs, [TaskTab.myTasks, TaskTab.private]);
    expect(cubit.state.tasksByTab.keys, isNot(contains(TaskTab.myTasks)));
    cubit.openWorkspace();
    expect(cubit.state.workspaceOpen, isTrue);
    expect(cubit.state.activeTab, TaskTab.myTasks);
    cubit.closeWorkspace();
    expect(cubit.state.workspaceOpen, isFalse);
    expect(cubit.state.activeTab, FakeTasksApi.tech);
  });

  test('my tasks: personal, assigned to me, and my reviews (0017)', () async {
    cubit.openWorkspace();
    final me = cubit.state.user!.id;
    final mine = cubit.state.tasks;
    // Every personal task.
    expect(
      mine.where((t) => t.personal).length,
      cubit.state.tasksByTab[TaskTab.private]!.length,
    );
    for (final t in mine.where((t) => !t.personal)) {
      final tab = cubit.state.tabOf(t)!;
      expect(
        t.assigneeId == me || (t.status == TaskStatus.review && canReview(tab)),
        isTrue,
        reason: t.name,
      );
    }
    // No task twice.
    expect(mine.map((t) => (t.id, t.personal)).toSet().length, mine.length);
  });

  test('my tasks: the dots count a review', () {
    cubit.openWorkspace();
    final review = cubit.state.tasks.firstWhere(
      (t) => t.status == TaskStatus.review && t.dueDate != null,
    );
    final day = dateOnly(review.dueDate!);
    expect(cubit.state.dueOn[day], contains(review));
  });

  test(
    'changing tab loads its tasks and keeps the day filter (0016)',
    () async {
      final oct14 = DateTime(2026, 10, 14);
      cubit.selectDay(oct14);
      await cubit.selectTab(FakeTasksApi.taskoWeb);
      expect(
        cubit.state.tasks.any((t) => t.name == 'Fix login redirect'),
        true,
      );
      expect(cubit.state.selectedDay, oct14);
      expect(cubit.state.listed, hasLength(5));
    },
  );

  test(
    'selecting a day filters and collapses; again keeps it (0016)',
    () async {
      await cubit.selectTab(FakeTasksApi.taskoWeb);
      final oct14 = DateTime(2026, 10, 14);
      cubit.selectDay(oct14);
      expect(cubit.state.listed, hasLength(5));
      expect(
        cubit.state.listed.every((t) => isSameDay(t.dueDate!, oct14)),
        true,
      );
      expect(cubit.state.showsWeek, isTrue);
      expect(cubit.state.week, DateTime(2026, 10, 12));
      cubit.selectDay(oct14);
      expect(cubit.state.selectedDay, oct14);
      expect(cubit.state.listed, hasLength(5));
    },
  );

  test('a day tap leaves the full-screen calendar', () {
    cubit.toggleCalendar();
    cubit.selectDay(DateTime(2026, 10, 20));
    expect(cubit.state.calendarExpanded, isFalse);
    expect(cubit.state.showsWeek, isTrue);
  });

  test('Today selects today from another month', () {
    cubit.changeMonth(2);
    cubit.goToToday();
    expect(cubit.state.selectedDay, DateTime(2026, 10, 7));
    expect(cubit.state.month, DateTime(2026, 10));
    expect(cubit.state.week, DateTime(2026, 10, 5));
  });

  test('swiping the week strip moves the week, not the selection', () async {
    await cubit.selectTab(FakeTasksApi.taskoWeb);
    final oct28 = DateTime(2026, 10, 28);
    cubit.selectDay(oct28);
    final listed = cubit.state.listed;
    cubit.changeWeek(1);
    expect(cubit.state.week, DateTime(2026, 11, 2));
    expect(cubit.state.month, DateTime(2026, 11));
    expect(cubit.state.selectedDay, oct28);
    expect(cubit.state.listed, listed);
    cubit.changeWeek(-2);
    expect(cubit.state.week, DateTime(2026, 10, 19));
    expect(cubit.state.month, DateTime(2026, 10));
  });

  test('folding to a week: the selected day, else today, else the first', () {
    cubit.foldToWeek();
    expect(cubit.state.showsWeek, isTrue);
    expect(cubit.state.week, DateTime(2026, 10, 5));
    cubit.openMonth();
    cubit.changeMonth(1);
    cubit.foldToWeek();
    expect(cubit.state.week, DateTime(2026, 10, 26)); // Nov 1's Monday
    cubit.selectDay(DateTime(2026, 11, 18));
    cubit.openMonth();
    cubit.foldToWeek();
    expect(cubit.state.week, DateTime(2026, 11, 16));
    expect(cubit.state.selectedDay, DateTime(2026, 11, 18));
  });

  test('clearing the day reopens the month', () {
    cubit.selectDay(DateTime(2026, 10, 14));
    cubit.clearDay();
    expect(cubit.state.selectedDay, isNull);
    expect(cubit.state.monthOpen, isTrue);
    cubit.selectDay(DateTime(2026, 10, 14));
    cubit.openMonth();
    expect(cubit.state.showsWeek, isFalse);
    expect(cubit.state.selectedDay, DateTime(2026, 10, 14));
  });

  test('changing month moves the calendar only', () {
    cubit.changeMonth(1);
    expect(cubit.state.month, DateTime(2026, 11));
    cubit.changeMonth(-2);
    expect(cubit.state.month, DateTime(2026, 9));
  });
}
