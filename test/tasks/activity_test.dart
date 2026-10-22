import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/tasks/activity_text.dart';
import 'package:tasko/tasks/http_tasks_api.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/task_rules.dart';
import 'package:tasko/tasks/tasks_api.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);
  late FakeTasksApi api;
  setUp(() => api = FakeTasksApi(today: now));

  const web = FakeTasksApi.taskoWeb;
  const app = FakeTasksApi.taskoApp;
  const tech = FakeTasksApi.tech;
  const budi = User(id: 3, name: 'Budi');

  ActivityEntry entry(
    String action,
    Map<String, dynamic> changes, {
    TaskTab tab = web,
    String type = 'task',
    String label = 'Deploy staging',
  }) => ActivityEntry(
    id: 1,
    action: action,
    actor: const User(id: 2, name: 'Ana'),
    actorName: 'Ana',
    subject: (type: type, id: 5, label: label),
    tab: tab,
    changes: changes,
    createdAt: now,
  );
  const inWeb = TabLog(web);
  const inTech = TabLog(tech);
  final inTask = TaskLog(
    const Task(id: 5, name: 'Deploy staging', status: TaskStatus.waiting),
  );
  String say(ActivityEntry e, ActivityScope scope) => sentence(e, scope, now);

  group('sentence', () {
    test(
      'every action the fake logs reads as a sentence, not its name',
      () async {
        // Mira's own log has her tasko-app deadline request, which no tab log she opens shows.
        final rows = [
          ...(await api.activity(inTech)).items,
          ...(await api.activity(inWeb)).items,
          ...(await api.activity(UserLog(FakeTasksApi.users.first))).items,
        ];
        final actions = {for (final e in rows) e.action};
        expect(actions, hasLength(26));
        for (final e in rows) {
          for (final scope in [inTech, inWeb, inTask, UserLog(budi)]) {
            expect(say(e, scope), isNot(contains(e.action)), reason: e.action);
          }
        }
      },
    );

    test('a task log leaves the task unnamed; elsewhere it is named', () {
      final started = entry('task.started', {});
      expect(say(started, inTask), 'Ana started it');
      expect(say(started, inWeb), 'Ana started Deploy staging');
      final comment = entry('comment.added', {'body': 'Keys are in the vault'});
      expect(say(comment, inTask), 'Ana commented: Keys are in the vault');
      expect(
        say(comment, inWeb),
        'Ana commented on Deploy staging: Keys are in the vault',
      );
    });

    test('edits show before → after', () {
      expect(
        say(
          entry('task.priority_changed', {
            'priority': [2, 3],
          }),
          inTask,
        ),
        'Ana changed the priority: medium → high',
      );
      expect(
        say(
          entry('task.due_changed', {
            'dueDate': ['2026-10-22T00:00:00Z', null],
          }),
          inWeb,
        ),
        startsWith('Ana moved the due date of Deploy staging: Oct 2'),
      );
      expect(
        say(
          entry('repeat.changed', {
            'repeat': [
              null,
              {
                'every': 1,
                'unit': 'week',
                'weekdays': [1, 4],
                'until': null,
                'count': null,
              },
            ],
          }),
          inTask,
        ),
        'Ana changed the repeat to every week on Mon and Thu',
      );
    });

    test('member rows name the project outside its own log', () {
      final removed = entry(
        'member.removed',
        {
          'role': 'member',
          'unassignedTaskIds': [1, 2],
        },
        type: 'member',
        label: 'Budi',
      );
      expect(say(removed, inWeb), 'Ana removed Budi; 2 tasks unassigned');
      expect(
        say(removed, inTech),
        'Ana removed Budi from tasko-web; 2 tasks unassigned',
      );
      final left = entry('member.left', {
        'role': 'member',
        'unassignedTaskIds': [],
      }, type: 'member');
      expect(say(left, inWeb), 'Ana left the project');
      expect(say(left, inTech), 'Ana left tasko-web');
    });

    test(
      'an unknown action, or changes of the wrong shape, read as the action',
      () {
        expect(say(entry('task.archived', {}), inWeb), 'Ana: task.archived');
        expect(
          say(entry('task.renamed', {'name': 'x'}), inWeb),
          'Ana: task.renamed',
        );
      },
    );
  });

  test(
    'log rules: division admins and supervisors; project owners and persons-in-charge',
    () {
      expect(
        canViewDivisionLog(
          const TaskTab(TabKind.division, 1, 'd', role: 'supervisor'),
        ),
        true,
      );
      expect(
        canViewDivisionLog(
          const TaskTab(TabKind.division, 1, 'd', role: 'member'),
        ),
        false,
      );
      expect(
        canViewProjectLog(
          const TaskTab(TabKind.project, 1, 'p', role: 'person-in-charge'),
        ),
        true,
      );
      expect(
        canViewProjectLog(
          const TaskTab(TabKind.project, 1, 'p', role: 'member'),
        ),
        false,
      );
      expect(
        canViewProjectLog(
          const TaskTab(TabKind.division, 1, 'd', role: 'admin'),
        ),
        false,
      );
    },
  );

  group('the fake keeps the server’s rules', () {
    // Mira is tech's supervisor, tasko-web's owner and a plain member of tasko-app.
    test(
      'the division log has its own rows and its projects’ member rows only',
      () async {
        final rows = (await api.activity(inTech)).items;
        expect(
          rows.every(
            (e) =>
                e.tab == tech ||
                e.action.startsWith('member.') ||
                e.action.startsWith('project.'),
          ),
          true,
        );
        expect(
          rows.any((e) => e.tab == app),
          true,
          reason: 'tasko-app member rows',
        );
        expect(rows.first.id > rows.last.id, true, reason: 'newest first');
      },
    );

    test('a project log needs its owner or person-in-charge', () async {
      expect((await api.activity(inWeb)).items, isNotEmpty);
      await expectLater(
        api.activity(const TabLog(app)),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
    });

    test('a task log follows its tab, and Task Detail says so', () async {
      final web = await api.tasksFor(FakeTasksApi.taskoWeb);
      final deploy = web.firstWhere((t) => t.name == 'Deploy staging');
      final rows = (await api.activity(TaskLog(deploy))).items;
      expect(rows.map((e) => e.subject.id).toSet(), {deploy.id});
      expect((await api.detail(deploy)).canViewLog, true);

      final ci = (await api.tasksFor(
        app,
      )).firstWhere((t) => t.name == 'Set up CI');
      expect((await api.detail(ci)).canViewLog, false);
      await expectLater(
        api.activity(TaskLog(ci)),
        throwsA(isA<ApiException>()),
      );
    });

    test(
      'a user log: by them or to them, opened by a lead of their division',
      () async {
        final rows = (await api.activity(UserLog(budi))).items;
        expect(rows, isNotEmpty);
        expect(rows.every((e) => e.actor?.id == 3 || e.target?.id == 3), true);
        await expectLater(
          api.activity(UserLog(FakeTasksApi.users.last)),
          throwsA(isA<ApiException>()),
          reason: 'Gita is in no division with Mira',
        );
      },
    );
  });
}
