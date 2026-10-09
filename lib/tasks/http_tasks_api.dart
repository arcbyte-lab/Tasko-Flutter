import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'tasks_api.dart';

/// Tasko-API's address. Point a debug build at a local `wrangler dev` with
/// `--dart-define=API_URL=http://10.0.2.2:8787`.
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://tasko-api.vidtandjung.workers.dev',
);

/// A non-2xx answer. The server's message is plain text, meant for the user.
class ApiException implements Exception {
  const ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

/// `POST /auth/login`: a 30-day bearer token and the user.
Future<(String, User)> login(
  String email,
  String password, {
  http.Client? client,
  String baseUrl = apiUrl,
}) async {
  final c = client ?? http.Client();
  final res = await c.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  if (client == null) c.close();
  if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return (json['token'] as String, _user(json['user']));
}

/// [TasksApi] over Tasko-API's routes. Every call carries [token]; a 401
/// (expired or logged out elsewhere) calls [onUnauthorized] before throwing.
class HttpTasksApi implements TasksApi {
  HttpTasksApi(
    this.token, {
    http.Client? client,
    this.baseUrl = apiUrl,
    this.onUnauthorized,
  }) : _client = client ?? http.Client();

  final String token;
  final String baseUrl;
  final void Function()? onUnauthorized;
  final http.Client _client;

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final res = await http.Response.fromStream(await _client.send(req));
    if (res.statusCode == 401) onUnauthorized?.call();
    if (res.statusCode >= 300) throw ApiException(res.statusCode, res.body);
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Future<dynamic> _get(String path) => _send('GET', path);

  String _tabPath(TaskTab tab) => '/tabs/${tab.kind.name}/${tab.id}';

  /// `/tasks/:id` or `/personal-tasks/:id`.
  String _taskPath(Task t) =>
      '/${t.personal ? 'personal-tasks' : 'tasks'}/${t.id}';

  /// `POST /auth/logout`: ends this token on the server.
  Future<void> logout() => _send('POST', '/auth/logout');

  @override
  Future<User> me() async => _user(await _get('/me'));

  @override
  Future<List<TaskTab>> myTabs() async => [
    for (final t in await _get('/tabs')) _tab(t),
  ];

  @override
  Future<List<Task>> tasksFor(TaskTab tab) async => [
    for (final t in await _get('${_tabPath(tab)}/tasks')) _task(t),
  ];

  @override
  Future<Task> setStatus(
    Task task,
    TaskStatus status, {
    String? proofUrl,
  }) async => _task(
    await _send('PATCH', '${_taskPath(task)}/status', {
      'status': status.name,
      'proofUrl': ?proofUrl,
    }),
  );

  @override
  Future<List<Member>> membersOf(TaskTab tab) async => [
    for (final m in await _get('${_tabPath(tab)}/members'))
      Member(_user(m['user']), m['role'] as String),
  ];

  @override
  Future<Task> createTask(
    TaskTab tab, {
    required String name,
    String? description,
    required Priority priority,
    DateTime? dueDate,
    int? assigneeId,
  }) async => _task(
    await _send('POST', '${_tabPath(tab)}/tasks', {
      'name': name,
      'description': description,
      'priority': priority.level,
      'dueDate': _date(dueDate),
      'assigneeId': ?assigneeId,
    }),
  );

  @override
  Future<Task> updateTask(Task task) async => _task(
    await _send('PATCH', _taskPath(task), {
      'name': task.name,
      'description': task.description,
      'priority': task.priority.level,
      'dueDate': _date(task.dueDate),
      if (!task.personal) 'assigneeId': task.assigneeId,
    }),
  );

  @override
  Future<TaskDetail> detail(Task task) async {
    final json = await _get('${_taskPath(task)}/detail');
    final proof = json['proof'];
    return TaskDetail(
      tab: _tab(json['tab']),
      subtasks: [for (final t in json['subtasks']) _task(t)],
      comments: [for (final c in json['comments']) _comment(c)],
      assignee: json['assignee'] == null ? null : _user(json['assignee']),
      proof: proof == null
          ? null
          : Proof(
              url: proof['url'] as String,
              author: _user(proof['author']),
              createdAt: _time(proof['createdAt'])!,
            ),
      canReview: json['canReview'] as bool,
      canArchive: json['canArchive'] as bool,
      canRequestExtension: json['canRequestExtension'] as bool,
    );
  }

  @override
  Future<Task> createSubtask(Task parent, String name) async => _task(
    await _send('POST', '${_taskPath(parent)}/subtasks', {'name': name}),
  );

  @override
  Future<Comment> addComment(Task task, String body) async => _comment(
    await _send('POST', '${_taskPath(task)}/comments', {'body': body}),
  );

  @override
  Future<Task> review(
    Task task, {
    required bool approve,
    String? reason,
  }) async => _task(
    await _send('POST', '/tasks/${task.id}/reviews', {
      'approve': approve,
      'reason': ?reason,
    }),
  );

  @override
  Future<void> requestExtension(Task task, DateTime newDue, String reason) =>
      _send('POST', '/tasks/${task.id}/deadline-requests', {
        'newDue': _date(newDue),
        'reason': reason,
      });

  @override
  Future<List<AppNotification>> notifications() async => [
    for (final n in await _get('/notifications'))
      AppNotification(
        id: n['id'] as String,
        text: n['text'] as String,
        createdAt: _time(n['createdAt'])!,
        actor: n['actor'] == null ? null : _user(n['actor']),
        readAt: _time(n['readAt']),
      ),
  ];

  @override
  Future<void> markRead(String notificationId) =>
      _send('POST', '/notifications/$notificationId/read');

  @override
  Future<void> markAllRead() => _send('POST', '/notifications/read-all');
}

/// The server speaks UTC ISO 8601; the app works in local time.
DateTime? _time(Object? s) =>
    s == null ? null : DateTime.parse(s as String).toLocal();

String? _date(DateTime? d) => d?.toUtc().toIso8601String();

User _user(dynamic j) => User(
  id: j['id'] as int,
  name: j['name'] as String,
  email: j['email'] as String?,
  mustChangePassword: j['mustChangePassword'] as bool? ?? false,
);

TaskTab _tab(dynamic j) => TaskTab(
  TabKind.values.byName(j['kind'] as String),
  j['id'] as int,
  j['name'] as String,
);

Comment _comment(dynamic j) => Comment(
  author: _user(j['author']),
  body: j['body'] as String,
  createdAt: _time(j['createdAt'])!,
);

Task _task(dynamic j) => Task(
  id: j['id'] as int,
  name: j['name'] as String,
  status: TaskStatus.values.byName(j['status'] as String),
  priority: Priority.fromLevel(j['priority'] as int),
  dueDate: _time(j['dueDate']),
  description: j['description'] as String?,
  assigneeId: j['assigneeId'] as int?,
  requiredProofType: j['requiredProofType'] as String?,
  personal: j['personal'] as bool,
  code: j['code'] as String?,
  parentId: j['parentId'] as int?,
  completedAt: _time(j['completedAt']),
);
