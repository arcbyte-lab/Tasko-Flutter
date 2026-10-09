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
}

const _task = Task(id: 7, name: 'x', status: TaskStatus.inProgress);
