import 'models.dart';

/// What the app needs from the server. The only seam in the app: the fake
/// below runs everything until the Laravel API lands.
abstract interface class TasksApi {
  Future<User> me();

  /// `private`, then the user's divisions, then their projects.
  Future<List<TaskTab>> myTabs();

  /// Top-level tasks only. A division tab holds only tasks with no project
  /// (arcbyte decision 0002).
  Future<List<Task>> tasksFor(TaskTab tab);

  /// The server sets completed_date / review_date alongside.
  Future<Task> setStatus(Task task, TaskStatus status);

  /// Who a task in [tab] can be assigned to, the current user first.
  Future<List<Member>> membersOf(TaskTab tab);

  /// Creates a task in [tab]: a personal task in `private`, otherwise a team
  /// task. The server fills in `code`, `division_id` and `creator_id`.
  Future<Task> createTask(
    TaskTab tab, {
    required String name,
    String? description,
    required Priority priority,
    DateTime? dueDate,
    int? assigneeId,
  });

  /// Saves [task]'s editable fields: name, description, priority, due date
  /// and assignee.
  Future<Task> updateTask(Task task);

  Future<TaskDetail> detail(Task task);

  Future<Task> createSubtask(Task parent, String name);

  Future<Comment> addComment(Task task, String body);

  /// A `task_reviews` row: approve → done, decline → in progress.
  Future<Task> review(Task task, {required bool approve, String? reason});

  /// A `task_deadline_requests` row.
  Future<void> requestExtension(Task task, DateTime newDue, String reason);

  /// The viewer's notifications, newest first.
  Future<List<AppNotification>> notifications();

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();
}

/// In-memory [TasksApi] seeded with the mockups' sample data, dated relative
/// to [today] so "today" and "overdue" always look right.
///
/// The viewer is Mira: author of tasko-web (so she reviews there) and a plain
/// member of tasko-app (so she can ask for extensions there).
class FakeTasksApi implements TasksApi {
  FakeTasksApi({required DateTime today})
    : _today = DateTime(today.year, today.month, today.day) {
    _seed();
  }

  final DateTime _today;
  final _tasks = <TaskTab, List<Task>>{};
  final _comments = <int, List<Comment>>{};
  final _creatorOf = <int, int>{};
  final _notifications = <AppNotification>[];

  /// What was sent, for tests to check.
  final reviews = <(int taskId, bool approve, String? reason)>[];
  final extensionRequests = <(int taskId, DateTime newDue, String reason)>[];

  static const tech = TaskTab(TabKind.division, 1, 'tech');
  static const taskoApp = TaskTab(TabKind.project, 1, 'tasko-app');
  static const taskoWeb = TaskTab(TabKind.project, 2, 'tasko-web');

  static const _me = User(id: 1, name: 'Mira', email: 'mira@arcbyte.dev');
  static const _ana = User(id: 2, name: 'Ana');
  static const _budi = User(id: 3, name: 'Budi');

  @override
  Future<User> me() async => _me;

  @override
  Future<List<TaskTab>> myTabs() async => [
    TaskTab.private,
    tech,
    taskoApp,
    taskoWeb,
  ];

  @override
  Future<List<Task>> tasksFor(TaskTab tab) async => [
    for (final t in _tasks[tab] ?? <Task>[])
      if (t.parentId == null) t,
  ];

  @override
  Future<Task> setStatus(Task task, TaskStatus status) async => _replace(
    task.copyWith(
      status: status,
      completedAt: () => status == TaskStatus.done ? DateTime.now() : null,
    ),
  );

  @override
  Future<List<Member>> membersOf(TaskTab tab) async {
    if (tab.kind == TabKind.private) return [];
    final lead = tab.kind == TabKind.project ? 'person-in-charge' : 'admin';
    return [
      const Member(_me, 'member'),
      Member(_ana, lead),
      for (final (i, name) in const [
        'Budi',
        'Citra',
        'Dimas',
        'Eka',
        'Fajar',
      ].indexed)
        Member(User(id: i + 3, name: name), 'member'),
    ];
  }

  @override
  Future<Task> createTask(
    TaskTab tab, {
    required String name,
    String? description,
    required Priority priority,
    DateTime? dueDate,
    int? assigneeId,
  }) async {
    final personal = tab.kind == TabKind.private;
    return _add(
      tab,
      Task(
        id: _nextId(),
        name: name,
        description: description,
        priority: priority,
        dueDate: dueDate,
        assigneeId: personal ? null : assigneeId,
        status: personal ? TaskStatus.todo : TaskStatus.waiting,
        personal: personal,
      ),
      creator: _me,
    );
  }

  @override
  Future<Task> updateTask(Task task) async => _replace(task);

  @override
  Future<TaskDetail> detail(Task task) async {
    final tab = _tabOf(task);
    final assignee = (await membersOf(
      tab,
    )).map((m) => m.user).where((u) => u.id == task.assigneeId).firstOrNull;
    final team = !task.personal;
    return TaskDetail(
      tab: tab,
      subtasks: [
        for (final t in _tasks[tab]!)
          if (t.parentId == task.id) t,
      ],
      comments: [...?_comments[task.id]],
      assignee: assignee,
      canReview: team && tab == taskoWeb,
      canArchive: team && _creatorOf[task.id] == _me.id,
      canRequestExtension: team && tab != taskoWeb && task.assigneeId == _me.id,
    );
  }

  @override
  Future<Task> createSubtask(Task parent, String name) async => _add(
    _tabOf(parent),
    Task(
      id: _nextId(),
      name: name,
      parentId: parent.id,
      personal: parent.personal,
      status: parent.personal ? TaskStatus.todo : TaskStatus.waiting,
      assigneeId: parent.assigneeId,
    ),
    creator: _me,
  );

  @override
  Future<Comment> addComment(Task task, String body) async {
    final c = Comment(author: _me, body: body, createdAt: DateTime.now());
    (_comments[task.id] ??= []).add(c);
    return c;
  }

  @override
  Future<Task> review(
    Task task, {
    required bool approve,
    String? reason,
  }) async {
    reviews.add((task.id, approve, reason));
    return setStatus(task, approve ? TaskStatus.done : TaskStatus.inProgress);
  }

  @override
  Future<void> requestExtension(
    Task task,
    DateTime newDue,
    String reason,
  ) async => extensionRequests.add((task.id, newDue, reason));

  @override
  Future<List<AppNotification>> notifications() async =>
      [..._notifications]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> markRead(String notificationId) async {
    final i = _notifications.indexWhere((n) => n.id == notificationId);
    if (i != -1) _notifications[i] = _notifications[i].markRead(DateTime.now());
  }

  @override
  Future<void> markAllRead() async {
    final now = DateTime.now();
    _notifications.setAll(0, _notifications.map((n) => n.markRead(now)));
  }

  TaskTab _tabOf(Task task) => _tasks.entries
      .firstWhere(
        (e) =>
            e.value.any((t) => t.id == task.id && t.personal == task.personal),
      )
      .key;

  int _nextId() =>
      _tasks.values
          .expand((l) => l)
          .fold(0, (max, t) => t.id > max ? t.id : max) +
      1;

  Task _add(TaskTab tab, Task task, {required User creator}) {
    (_tasks[tab] ??= []).add(task);
    _creatorOf[task.id] = creator.id;
    return task;
  }

  Task _replace(Task updated) {
    for (final list in _tasks.values) {
      final i = list.indexWhere(
        (t) => t.id == updated.id && t.personal == updated.personal,
      );
      if (i != -1) list[i] = updated;
    }
    return updated;
  }

  void _seed() {
    DateTime day(int offset, [int hour = 0]) =>
        _today.add(Duration(days: offset, hours: hour));
    var webCode = 40, appCode = 10;
    Task t(
      TaskTab tab,
      String name,
      Priority priority,
      TaskStatus status,
      int? due, {
      String? proof,
      String? note,
      int hour = 0,
      int assignee = 1,
    }) => _add(
      tab,
      Task(
        id: _nextId(),
        name: name,
        priority: priority,
        status: status,
        dueDate: due == null ? null : day(due, hour),
        requiredProofType: proof,
        description: note,
        assigneeId: assignee,
        code: tab == taskoWeb
            ? 'TW-${(++webCode).toString().padLeft(4, '0')}'
            : 'TA-${(++appCode).toString().padLeft(4, '0')}',
        completedAt: status == TaskStatus.done ? day(due ?? 0) : null,
      ),
      creator: _ana,
    );
    Task p(String name, Priority priority, TaskStatus status, int? due) => _add(
      TaskTab.private,
      Task(
        id: _nextId(),
        name: name,
        priority: priority,
        status: status,
        dueDate: due == null ? null : day(due),
        personal: true,
        completedAt: status == TaskStatus.done ? day(due ?? 0) : null,
      ),
      creator: _me,
    );
    Task sub(Task parent, String name, {bool done = false}) => _add(
      _tabOf(parent),
      Task(
        id: _nextId(),
        name: name,
        parentId: parent.id,
        personal: parent.personal,
        assigneeId: parent.assigneeId,
        status: done
            ? TaskStatus.done
            : (parent.personal ? TaskStatus.todo : TaskStatus.waiting),
      ),
      creator: _me,
    );

    final (low, medium, high, urgent) = (
      Priority.low,
      Priority.medium,
      Priority.high,
      Priority.urgent,
    );
    final (waiting, inProgress, review, done, todo) = (
      TaskStatus.waiting,
      TaskStatus.inProgress,
      TaskStatus.review,
      TaskStatus.done,
      TaskStatus.todo,
    );

    _tasks[TaskTab.private] = [];
    _tasks[tech] = [];
    final domain = p('Buy domain', medium, todo, 3);
    p('Renew passport', high, todo, 2);
    p('Book dentist', medium, inProgress, 0);
    p('Pay internet bill', urgent, todo, -2);
    p('Read Flutter release notes', low, todo, null);
    p('Buy groceries', medium, done, -1);
    sub(domain, 'Compare registrars', done: true);
    sub(domain, 'Set up DNS');

    t(taskoApp, 'Set up CI', high, inProgress, 1);
    t(taskoApp, 'Port theme tokens', medium, waiting, 3);
    t(taskoApp, 'Draft API contract', medium, waiting, 3);
    t(taskoApp, 'Pick an icon set', low, done, -3);

    final login = t(
      taskoWeb,
      'Fix login redirect',
      urgent,
      inProgress,
      -4,
      hour: 17,
      proof: 'image',
      note:
          'After login, users land on /home instead of the page they came '
          'from. Keep the return URL and redirect back.',
    );
    t(taskoWeb, 'Write onboarding copy', medium, waiting, 0);
    t(taskoWeb, 'Review PR #42', high, review, 0, proof: 'image', assignee: 3);
    t(taskoWeb, 'Deploy staging', high, waiting, 1);
    t(
      taskoWeb,
      'Upload release screenshots',
      medium,
      waiting,
      2,
      proof: 'image',
    );
    t(taskoWeb, 'Design empty state', low, waiting, 7);
    t(taskoWeb, 'Fix navbar on mobile', high, inProgress, 7);
    t(taskoWeb, 'QA checkout flow', medium, review, 7, proof: 'file');
    t(taskoWeb, 'Write release notes', medium, waiting, 7);
    t(taskoWeb, 'Add 404 page', low, waiting, 7);
    t(taskoWeb, 'Update favicon', low, inProgress, 13);
    t(taskoWeb, 'Clean up old branches', low, waiting, null);
    t(taskoWeb, 'Set up analytics', medium, done, -2);
    t(taskoWeb, 'Fix footer links', low, done, -5);
    t(taskoWeb, 'Compress hero images', low, done, -6);
    sub(login, 'Reproduce on Safari', done: true);
    sub(login, 'Store return URL');
    sub(login, 'Add redirect test');

    final now = DateTime.now();
    var n = 0;
    void note(String text, Duration ago, {User? actor, bool read = false}) =>
        _notifications.add(
          AppNotification(
            id: 'n${++n}',
            text: text,
            actor: actor,
            createdAt: now.subtract(ago),
            readAt: read ? now : null,
          ),
        );
    note(
      'Ana assigned you Deploy staging',
      const Duration(minutes: 5),
      actor: _ana,
    );
    note(
      'Your extension request for Fix login redirect was approved',
      const Duration(hours: 1),
    );
    note('Write onboarding copy is due today', const Duration(hours: 2));
    note(
      'Budi commented on Review PR #42',
      const Duration(days: 1),
      actor: _budi,
      read: true,
    );
    note(
      'Citra moved Design empty state to in progress',
      const Duration(days: 1, hours: 2),
      actor: const User(id: 4, name: 'Citra'),
      read: true,
    );
    note(
      'Dimas mentioned you in Update favicon',
      const Duration(days: 2),
      actor: const User(id: 5, name: 'Dimas'),
      read: true,
    );
    note(
      'Budi marked Pick an icon set as done',
      const Duration(days: 2, hours: 3),
      actor: _budi,
      read: true,
    );

    _comments[login.id] = [
      Comment(
        author: _ana,
        body: 'Only happens on Safari for me. Chrome is fine.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Comment(
        author: _budi,
        body: "Can this ship before Friday's release?",
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
    ];
  }
}
