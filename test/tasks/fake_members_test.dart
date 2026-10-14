import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/tasks/http_tasks_api.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/tasks_api.dart';

/// The fake refuses what Tasko-API refuses, so Cubit tests see real failures.
void main() {
  late FakeTasksApi api;
  setUp(() => api = FakeTasksApi(today: DateTime(2026, 10, 14)));

  const web = FakeTasksApi.taskoWeb, app = FakeTasksApi.taskoApp;
  Matcher refused(int status) =>
      throwsA(isA<ApiException>().having((e) => e.status, 'status', status));

  test('the viewer’s roles come with the tabs', () async {
    expect((await api.myTabs()).map((t) => t.role), [
      null,
      'supervisor',
      'member',
      'owner',
    ]);
  });

  test('a supervisor creates a project and owns it', () async {
    final tab = await api.createProject(1, ' Launch ');
    expect((tab.name, tab.role), ('Launch', 'owner'));
    expect((await api.myTabs()).last, tab);
    expect((await api.membersOf(tab)).single.role, 'owner');
  });

  test('add, re-role and remove follow the owner rules', () async {
    final gita = (await api.searchUsers('GITA')).single;
    expect((await api.addMember(web, gita.id)).role, 'member');
    await expectLater(api.addMember(web, gita.id), refused(409));
    await expectLater(api.addMember(app, gita.id), refused(403));
    await expectLater(api.setMemberRole(web, 1, 'member'), refused(422));
    await api.setMemberRole(web, 2, 'owner');
    await api.setMemberRole(web, 1, 'member');
    await expectLater(api.setMemberRole(web, 2, 'member'), refused(403));
  });

  test('leaving drops the tab and unassigns open tasks, not review', () async {
    await api.setMemberRole(web, 2, 'owner');
    await api.removeMember(web, 1);
    expect(await api.myTabs(), isNot(contains(web)));
    final mine = [
      for (final t in await api.tasksFor(web))
        if (t.assigneeId == 1) t.status,
    ];
    expect(mine, everyElement(anyOf(TaskStatus.review, TaskStatus.done)));
    expect(mine, contains(TaskStatus.review));
  });

  test('the last owner can’t leave', () async {
    await expectLater(api.removeMember(web, 1), refused(422));
  });
}
