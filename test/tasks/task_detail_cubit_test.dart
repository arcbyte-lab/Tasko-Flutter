import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/task_detail_cubit.dart';
import 'package:tasko/tasks/task_rules.dart';
import 'package:tasko/tasks/tasks_api.dart';

void main() {
  late FakeTasksApi api;

  setUp(() => api = FakeTasksApi(today: DateTime(2026, 10, 7)));

  Future<TaskDetailCubit> open(TaskTab tab, String name) async {
    final task = (await api.tasksFor(tab)).firstWhere((t) => t.name == name);
    final cubit = TaskDetailCubit(api, task);
    await cubit.load();
    return cubit;
  }

  Future<Task> stored(TaskTab tab, String name) async =>
      (await api.tasksFor(tab)).firstWhere((t) => t.name == name);

  test('loads sub-tasks, comments, assignee and the action', () async {
    final c = await open(FakeTasksApi.taskoWeb, 'Fix login redirect');
    final d = c.state.detail!;
    expect(d.tab, FakeTasksApi.taskoWeb);
    expect(d.subtasks.map((t) => t.name), [
      'Reproduce on Safari',
      'Store return URL',
      'Add redirect test',
    ]);
    expect(d.comments, hasLength(2));
    expect(d.assignee?.name, 'Mira');
    expect(c.state.action, DetailAction.submitProof);
  });

  test('sub-tasks are not listed as tasks', () async {
    final names = (await api.tasksFor(
      FakeTasksApi.taskoWeb,
    )).map((t) => t.name);
    expect(names, isNot(contains('Store return URL')));
  });

  test('rename trims; a blank name is ignored', () async {
    final c = await open(FakeTasksApi.taskoWeb, 'Deploy staging');
    await c.rename('   ');
    expect(c.state.task.name, 'Deploy staging');
    await c.rename('  Deploy staging v2 ');
    expect(
      (await stored(FakeTasksApi.taskoWeb, 'Deploy staging v2')).id,
      c.state.task.id,
    );
  });

  test('a blank note is saved as null', () async {
    final c = await open(FakeTasksApi.taskoWeb, 'Fix login redirect');
    await c.setNote('  ');
    expect(c.state.task.description, isNull);
  });

  test('changing the assignee shows the new one', () async {
    final c = await open(FakeTasksApi.taskoWeb, 'Deploy staging');
    final ana = (await api.membersOf(FakeTasksApi.taskoWeb))[1];
    await c.setAssignee(ana);
    expect(c.state.detail!.assignee?.name, 'Ana');
    expect(c.state.action, DetailAction.none); // no longer mine
  });

  test('start working, then mark done', () async {
    final c = await open(FakeTasksApi.taskoWeb, 'Deploy staging');
    expect(c.state.action, DetailAction.startWorking);
    await c.startWorking();
    expect(c.state.task.status, TaskStatus.inProgress);
    expect(c.state.action, DetailAction.markDone);
    await c.markDone();
    expect(c.state.task.status, TaskStatus.done);
    expect(c.state.task.completedAt, isNotNull);
    expect(c.state.action, DetailAction.done);
  });

  test('a reviewer approves or rejects with a reason', () async {
    final qa = await open(FakeTasksApi.taskoWeb, 'QA checkout flow');
    expect(qa.state.action, DetailAction.review);
    await qa.approve();
    expect(qa.state.task.status, TaskStatus.done);

    final pr = await open(FakeTasksApi.taskoWeb, 'Review PR #42');
    await pr.reject('Tests are missing');
    expect(pr.state.task.status, TaskStatus.inProgress);
    expect(api.reviews, [
      (qa.state.task.id, true, null),
      (pr.state.task.id, false, 'Tests are missing'),
    ]);
  });

  test('sub-tasks: tick and add', () async {
    final c = await open(FakeTasksApi.taskoWeb, 'Fix login redirect');
    await c.tickSubtask(c.state.detail!.subtasks[1]);
    expect(
      c.state.detail!.subtasks.where((t) => t.status == TaskStatus.done),
      hasLength(2),
    );
    await c.addSubtask('   ');
    await c.addSubtask(' Ship it ');
    expect(c.state.detail!.subtasks.last.name, 'Ship it');
    expect(c.state.detail!.subtasks, hasLength(4));
  });

  test('comments are trimmed; blank ones are dropped', () async {
    final c = await open(FakeTasksApi.taskoWeb, 'Fix login redirect');
    await c.addComment('  ');
    await c.addComment(' On it. ');
    expect(c.state.detail!.comments.map((x) => x.body).last, 'On it.');
    expect(c.state.detail!.comments, hasLength(3));
  });

  test('a member can ask for an extension', () async {
    final c = await open(FakeTasksApi.taskoApp, 'Set up CI');
    expect(c.state.detail!.canRequestExtension, isTrue);
    await c.requestExtension(DateTime(2026, 10, 12, 9), 'Waiting on access');
    expect(api.extensionRequests.single.$3, 'Waiting on access');
  });

  test('personal tasks: no review, no extension', () async {
    final c = await open(TaskTab.private, 'Buy domain');
    final d = c.state.detail!;
    expect(d.subtasks, hasLength(2));
    expect(d.canReview || d.canRequestExtension || d.canArchive, isFalse);
    expect(c.state.action, DetailAction.startWorking);
  });

  test('no emit after close', () async {
    final c = await open(FakeTasksApi.taskoWeb, 'Deploy staging');
    final pending = c.rename('Late rename');
    await c.close();
    await pending; // would throw StateError without the guard
  });
}
