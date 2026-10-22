import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tasko/tasks/http_tasks_api.dart';
import 'package:tasko/tasks/models.dart';

/// Shapes as Tasko-API's `toTask` writes them.
const _row = {
  'id': 7,
  'name': 'Upload screenshots',
  'status': 'inProgress',
  'priority': 4,
  'dueDate': '2026-10-09T10:00:00Z',
  'description': null,
  'assigneeId': 1,
  'requiredProofType': 'image',
  'personal': false,
  'code': 'TW-0007',
  'parentId': null,
  'completedAt': null,
};

void main() {
  late List<http.Request> sent;
  late http.Response Function(http.Request) reply;
  var unauthorized = 0;

  HttpTasksApi api() => HttpTasksApi(
    'tok',
    baseUrl: 'https://api.test',
    onUnauthorized: () => unauthorized++,
    client: MockClient((req) async {
      sent.add(req);
      return reply(req);
    }),
  );

  setUp(() {
    sent = [];
    unauthorized = 0;
  });

  test('reads a task and sends a proof link with the tick', () async {
    reply = (_) =>
        http.Response(jsonEncode({..._row, 'status': 'review'}), 200);
    final task = await api().setStatus(
      const Task(id: 7, name: 'x', status: TaskStatus.inProgress),
      TaskStatus.review,
      proofUrl: 'https://example.com/a.png',
    );

    final req = sent.single;
    expect(req.method, 'PATCH');
    expect(req.url.toString(), 'https://api.test/tasks/7/status');
    expect(req.headers['authorization'], 'Bearer tok');
    expect(jsonDecode(req.body), {
      'status': 'review',
      'proofUrl': 'https://example.com/a.png',
    });
    expect(task.status, TaskStatus.review);
    expect(task.priority, Priority.urgent);
    expect(task.dueDate, DateTime.utc(2026, 10, 9, 10).toLocal());
    expect(task.code, 'TW-0007');
  });

  test('priority goes out as 1–4; personal tasks have no assignee', () async {
    reply = (_) => http.Response(jsonEncode({..._row, 'personal': true}), 200);
    await api().updateTask(
      const Task(
        id: 3,
        name: 'Book dentist',
        status: TaskStatus.todo,
        priority: Priority.low,
        personal: true,
      ),
    );
    expect(sent.single.url.path, '/personal-tasks/3');
    expect(jsonDecode(sent.single.body), {
      'name': 'Book dentist',
      'description': null,
      'priority': 1,
      'dueDate': null,
    });
  });

  test('a repeat rule goes out and comes back; until is a plain day', () async {
    const rule = {
      'every': 2,
      'unit': 'week',
      'weekdays': [1, 4],
      'until': '2026-12-31',
      'count': null,
    };
    reply = (_) => http.Response(jsonEncode({..._row, 'repeat': rule}), 200);
    final task = await api().updateTask(
      _task.copyWith(
        repeat: () => Repeat(
          every: 2,
          weekdays: const [1, 4],
          until: DateTime(2026, 12, 31),
        ),
      ),
    );
    expect(jsonDecode(sent.single.body)['repeat'], rule);
    expect(task.repeat!.unit, RepeatUnit.week);
    expect(task.repeat!.until, DateTime(2026, 12, 31));
  });

  test('an error carries the server message; 401 logs out', () async {
    reply = (_) => http.Response('Only the assignee can change this task', 403);
    await expectLater(
      api().setStatus(_task, TaskStatus.done),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Only the assignee can change this task',
        ),
      ),
    );
    expect(unauthorized, 0);

    reply = (_) => http.Response('Unauthorized', 401);
    await expectLater(api().me(), throwsA(isA<ApiException>()));
    expect(unauthorized, 1);
  });

  test('reads mustChangePassword', () async {
    reply = (_) => http.Response(
      jsonEncode({
        'id': 1,
        'name': 'Mira',
        'email': 'mira@arcbyte.dev',
        'mustChangePassword': true,
      }),
      200,
    );
    expect((await api().me()).mustChangePassword, isTrue);
  });

  test('tabs carry the viewer’s role', () async {
    reply = (_) => http.Response(
      jsonEncode([
        {'kind': 'private', 'id': 0, 'name': 'private', 'role': null},
        {'kind': 'project', 'id': 2, 'name': 'tasko-web', 'role': 'owner'},
      ]),
      200,
    );
    final tabs = await api().myTabs();
    expect(tabs.map((t) => t.role), [null, 'owner']);
  });

  test('creates a project; its due date goes out as the local day', () async {
    reply = (_) => http.Response(
      jsonEncode({
        'kind': 'project',
        'id': 9,
        'name': 'Launch',
        'role': 'owner',
      }),
      201,
    );
    final tab = await api().createProject(
      1,
      'Launch',
      dueDate: DateTime(2026, 12, 31),
    );

    final req = sent.single;
    expect(
      (req.method, req.url.toString()),
      ('POST', 'https://api.test/projects'),
    );
    expect(jsonDecode(req.body), {
      'divisionId': 1,
      'name': 'Launch',
      'dueDate': '2026-12-31',
    });
    expect((tab.kind, tab.id, tab.role), (TabKind.project, 9, 'owner'));
  });

  test('searches users with an encoded query', () async {
    reply = (_) => http.Response(
      jsonEncode([
        {'id': 3, 'name': 'Budi', 'email': 'budi@arcbyte.dev'},
      ]),
      200,
    );
    final users = await api().searchUsers('budi & co');
    expect(sent.single.url.toString(), 'https://api.test/users?q=budi+%26+co');
    expect(users.single.email, 'budi@arcbyte.dev');
  });

  test('adds, re-roles and removes members', () async {
    const project = TaskTab(TabKind.project, 2, 'tasko-web');
    const budi = {
      'user': {'id': 3, 'name': 'Budi'},
      'role': 'viewer',
    };
    reply = (_) => http.Response(jsonEncode(budi), 200);

    final added = await api().addMember(project, 3, role: 'viewer');
    final changed = await api().setMemberRole(project, 3, 'viewer');
    reply = (_) => http.Response('', 204);
    await api().removeMember(project, 3);

    expect(
      [for (final r in sent) '${r.method} ${r.url.path}'],
      [
        'POST /projects/2/members',
        'PATCH /projects/2/members/3',
        'DELETE /projects/2/members/3',
      ],
    );
    expect(jsonDecode(sent[0].body), {'userId': 3, 'role': 'viewer'});
    expect(jsonDecode(sent[1].body), {'role': 'viewer'});
    expect((added.user.name, added.role), ('Budi', 'viewer'));
    expect(changed.role, 'viewer');
  });

  test(
    'reads repeating series and history, and deletes a series (0012)',
    () async {
      final task = {..._row, 'seriesId': 3};
      reply = (req) => switch (req.url.path) {
        '/divisions/1/repeating' => http.Response(
          jsonEncode([
            {
              'task': task,
              'rule': {
                'every': 1,
                'unit': 'week',
                'weekdays': [1],
                'until': null,
                'count': null,
              },
              'ended': true,
              'recent': [
                {
                  'dueDate': '2026-10-05T02:00:00Z',
                  'finishedAt': '2026-10-05T01:00:00Z',
                  'onTime': true,
                },
                {
                  'dueDate': '2026-09-28T02:00:00Z',
                  'finishedAt': '2026-09-30T01:00:00Z',
                  'onTime': false,
                },
              ],
            },
          ]),
          200,
        ),
        '/series/3' when req.method == 'GET' => http.Response(
          jsonEncode([
            {
              'task': task,
              'finishedAt': null,
              'onTime': null,
              'proofUrl': null,
            },
            {
              'task': task,
              'finishedAt': '2026-10-05T01:00:00Z',
              'onTime': true,
              'proofUrl': 'https://example.com/p',
            },
          ]),
          200,
        ),
        _ => http.Response('', 204),
      };
      final series = (await api().repeatingFor(
        const TaskTab(TabKind.division, 1, 'tech'),
      )).single;
      expect(series.task.seriesId, 3);
      expect(series.recent, [true, false]);
      expect(series.rule.weekdays, [1]);
      expect(series.ended, isTrue);

      final history = await api().seriesHistory(3);
      expect(history.map((o) => o.onTime), [null, true]);
      expect(history.last.proofUrl, 'https://example.com/p');
      expect(history.last.finishedAt, DateTime.utc(2026, 10, 5, 1).toLocal());

      await api().deleteSeries(3);
      expect((sent.last.method, sent.last.url.path), ('DELETE', '/series/3'));
    },
  );

  test(
    'activity: one route per log, a page of rows and the next cursor',
    () async {
      reply = (_) => http.Response(
        jsonEncode({
          'items': [
            {
              'id': 41,
              'action': 'task.assigned',
              'actor': {'id': 2, 'name': 'Ana'},
              'subject': {'type': 'task', 'id': 1, 'label': 'Set up CI'},
              'target': {'id': 3, 'name': 'Budi'},
              'tab': {'kind': 'project', 'id': 1, 'name': 'tasko-app'},
              'changes': {
                'assigneeId': [1, 3],
                'assigneeName': 'Budi',
              },
              'createdAt': '2026-10-20T02:00:00Z',
            },
            {
              'id': 40,
              'action': 'member.left',
              'actor': {'id': null, 'name': 'Gone'},
              'subject': {'type': 'member', 'id': 9, 'label': 'Gone'},
              'target': null,
              'tab': {'kind': 'project', 'id': 4, 'name': null},
              'changes': null,
              'createdAt': '2026-10-19T02:00:00Z',
            },
          ],
          'next': 40,
        }),
        200,
      );
      final page = await api().activity(const TaskLog(_task), before: 50);
      expect(
        sent.single.url.toString(),
        'https://api.test/tasks/7/activity?before=50',
      );
      expect(page.next, 40);
      final [assigned, left] = page.items;
      expect(
        (
          assigned.actor!.name,
          assigned.target!.name,
          assigned.subject.label,
          assigned.tab.kind,
        ),
        ('Ana', 'Budi', 'Set up CI', TabKind.project),
      );
      expect(assigned.changes['assigneeName'], 'Budi');
      expect(assigned.createdAt, DateTime.utc(2026, 10, 20, 2).toLocal());
      expect((left.actor, left.actorName, left.tab.name), (null, 'Gone', ''));
      expect(left.changes, isEmpty);

      await api().activity(
        const TabLog(TaskTab(TabKind.project, 2, 'tasko-web')),
      );
      await api().activity(const TabLog(TaskTab(TabKind.division, 1, 'tech')));
      await api().activity(const UserLog(User(id: 3, name: 'Budi')));
      expect(
        [for (final r in sent.skip(1)) r.url.path],
        ['/projects/2/activity', '/divisions/1/activity', '/users/3/activity'],
      );
    },
  );

  test(
    'Task Detail reads canViewLog, false when the server leaves it out',
    () async {
      Map<String, Object?> detail([bool? log]) => {
        'tab': {'kind': 'project', 'id': 1, 'name': 'tasko-app'},
        'subtasks': [],
        'comments': [],
        'assignee': null,
        'proof': null,
        'canReview': false,
        'canArchive': false,
        'canRequestExtension': false,
        'canViewLog': ?log,
      };
      reply = (_) => http.Response(jsonEncode(detail(true)), 200);
      expect((await api().detail(_task)).canViewLog, isTrue);
      reply = (_) => http.Response(jsonEncode(detail()), 200);
      expect((await api().detail(_task)).canViewLog, isFalse);
    },
  );
}

const _task = Task(id: 7, name: 'x', status: TaskStatus.inProgress);
