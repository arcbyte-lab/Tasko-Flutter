import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/tasks/create_task_cubit.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/tasks_api.dart';

void main() {
  late FakeTasksApi api;

  setUp(() => api = FakeTasksApi(today: DateTime(2026, 10, 7)));

  Future<CreateTaskCubit> cubitFor(TaskTab tab) async {
    final cubit = CreateTaskCubit(api, tab);
    await cubit.load();
    return cubit;
  }

  test('a team task defaults to medium and to me', () async {
    final cubit = await cubitFor(FakeTasksApi.taskoWeb);
    expect(cubit.state.priority, Priority.medium);
    expect(cubit.state.assignee?.user.name, 'Mira');
    expect(cubit.state.members, hasLength(7));
  });

  test('a personal task has no members and no assignee', () async {
    final cubit = await cubitFor(TaskTab.private);
    expect(cubit.state.members, isEmpty);
    expect(cubit.state.assignee, isNull);
  });

  test('a blank title cannot be submitted', () async {
    final cubit = await cubitFor(FakeTasksApi.taskoWeb);
    cubit.setName('   ');
    expect(cubit.state.canSubmit, isFalse);
    expect(await cubit.submit(), isNull);
  });

  test('submit trims, drops a blank note, and lands in the tab', () async {
    final cubit = await cubitFor(FakeTasksApi.taskoWeb);
    final ana = cubit.state.members[1];
    cubit
      ..setName('  Prepare demo ')
      ..setNote('   ')
      ..setPriority(Priority.high)
      ..setDueDate(DateTime(2026, 10, 9, 9))
      ..setAssignee(ana);
    final task = (await cubit.submit())!;

    expect(task.name, 'Prepare demo');
    expect(task.description, isNull);
    expect(task.priority, Priority.high);
    expect(task.dueDate, DateTime(2026, 10, 9, 9));
    expect(task.assigneeId, ana.user.id);
    expect(task.status, TaskStatus.waiting);
    expect(task.personal, isFalse);
    expect(
      (await api.tasksFor(FakeTasksApi.taskoWeb)).map((t) => t.id),
      contains(task.id),
    );
  });

  test('a personal task starts as to do', () async {
    final cubit = await cubitFor(TaskTab.private);
    cubit
      ..setName('Call mum')
      ..setNote(' tonight ');
    final task = (await cubit.submit())!;
    expect(task.personal, isTrue);
    expect(task.status, TaskStatus.todo);
    expect(task.description, 'tonight');
  });
}
