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

  test('changing tab loads its tasks and clears the day filter', () async {
    cubit.selectDay(DateTime(2026, 10, 14));
    await cubit.selectTab(FakeTasksApi.taskoWeb);
    expect(cubit.state.tasks.any((t) => t.name == 'Fix login redirect'), true);
    expect(cubit.state.selectedDay, isNull);
  });

  test('selecting a day filters; selecting it again clears', () async {
    await cubit.selectTab(FakeTasksApi.taskoWeb);
    final oct14 = DateTime(2026, 10, 14);
    cubit.selectDay(oct14);
    expect(cubit.state.listed, hasLength(5));
    expect(cubit.state.listed.every((t) => isSameDay(t.dueDate!, oct14)), true);
    cubit.selectDay(oct14);
    expect(cubit.state.selectedDay, isNull);
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

  test('a task that needs a proof throws and does not change', () async {
    await cubit.selectTab(FakeTasksApi.taskoWeb);
    final t = named('Upload release screenshots');
    await expectLater(cubit.tick(t), throwsA(isA<ProofRequired>()));
    expect(named('Upload release screenshots').status, TaskStatus.waiting);
  });

  test('the change survives switching tabs (the API kept it)', () async {
    await cubit.tick(named('Renew passport'));
    await cubit.selectTab(FakeTasksApi.tech);
    await cubit.selectTab(TaskTab.private);
    expect(named('Renew passport').status, TaskStatus.done);
  });
}
