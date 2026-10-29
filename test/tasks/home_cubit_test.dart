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

  Task named(String name) =>
      cubit.state.tasks.firstWhere((t) => t.name == name);

  test('loads private first, then divisions, then projects', () {
    expect(cubit.state.tabs.map((t) => t.name), [
      'private',
      'tech',
      'tasko-app',
      'tasko-web',
    ]);
    expect(cubit.state.activeTab, TaskTab.private);
    expect(cubit.state.tasks.every((t) => t.personal), isTrue);
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

  test('ticking a team task: done, out of the counts, and back', () async {
    await cubit.selectTab(FakeTasksApi.taskoWeb);
    final before = cubit.state.dueCountsThisMonth[7]!;
    await cubit.tick(named('Write onboarding copy'));
    expect(named('Write onboarding copy').status, TaskStatus.done);
    expect(cubit.state.dueCountsThisMonth[7] ?? 0, before - 1);
    await cubit.tick(named('Write onboarding copy'));
    expect(named('Write onboarding copy').status, TaskStatus.waiting);
  });

  test('a task in review does not change', () async {
    await cubit.selectTab(FakeTasksApi.taskoWeb);
    await cubit.tick(named('Review PR #42'));
    expect(named('Review PR #42').status, TaskStatus.review);
  });

  test(
    'a task that needs a proof waits for a link, then goes to review',
    () async {
      await cubit.selectTab(FakeTasksApi.taskoWeb);
      final t = named('Upload release screenshots');
      await expectLater(cubit.tick(t), throwsA(isA<ProofRequired>()));
      expect(named('Upload release screenshots').status, TaskStatus.waiting);
      await cubit.tick(t, proofUrl: 'https://example.com/shot.png');
      expect(named('Upload release screenshots').status, TaskStatus.review);
    },
  );

  test('the change survives switching tabs (the API kept it)', () async {
    await cubit.tick(named('Renew passport'));
    await cubit.selectTab(FakeTasksApi.tech);
    await cubit.selectTab(TaskTab.private);
    expect(named('Renew passport').status, TaskStatus.done);
  });
}
