import 'http_tasks_api.dart' show ApiException;
import 'models.dart';
import 'task_rules.dart';

/// What the app needs from the server. The only seam in the app:
/// [HttpTasksApi] talks to Tasko-API; the fake below runs the tests.
abstract interface class TasksApi {
  Future<User> me();

  /// `private`, then the user's divisions, then their projects.
  Future<List<TaskTab>> myTabs();

  /// Top-level tasks only. A division tab holds only tasks with no project
  /// (arcbyte decision 0002).
  Future<List<Task>> tasksFor(TaskTab tab);

  /// The server sets completed_date / review_date alongside. Moving to
  /// review needs [proofUrl] (arcbyte decision 0007).
  Future<Task> setStatus(Task task, TaskStatus status, {String? proofUrl});

  /// Who a task in [tab] can be assigned to, the current user first.
  Future<List<Member>> membersOf(TaskTab tab);

  /// Creates a task in [tab]: a personal task in `private`, otherwise a team
  /// task. The server fills in `code`, `division_id` and `creator_id`. A
  /// [repeat] needs a division lead and a due date (arcbyte decision 0012).
  Future<Task> createTask(
    TaskTab tab, {
    required String name,
    String? description,
    required Priority priority,
    DateTime? dueDate,
    int? assigneeId,
    Repeat? repeat,
  });

  /// Saves [task]'s editable fields: name, description, priority, due date
  /// and assignee.
  Future<Task> updateTask(Task task);

  Future<TaskDetail> detail(Task task);

  Future<Task> createSubtask(Task parent, String name);

  Future<Comment> addComment(Task task, String body);

  /// A `task_reviews` row: approve → done, reject → in progress.
  Future<Task> review(Task task, {required bool approve, String? reason});

  /// A `task_deadline_requests` row.
  Future<void> requestExtension(Task task, DateTime newDue, String reason);

  /// The viewer's notifications, newest first.
  Future<List<AppNotification>> notifications();

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();

  /// A project in division [divisionId]; the viewer becomes its owner. The
  /// returned tab carries `role: 'owner'` (arcbyte decision 0010).
  Future<TaskTab> createProject(
    int divisionId,
    String name, {
    String? description,
    DateTime? dueDate,
  });

  /// Up to 20 active users whose name or email contains [q], for the member
  /// picker.
  Future<List<User>> searchUsers(String q);

  /// Adds [userId] to [project] directly: there is no invitation step.
  Future<Member> addMember(
    TaskTab project,
    int userId, {
    String role = 'member',
  });

  Future<Member> setMemberRole(TaskTab project, int userId, String role);

  /// Removes [userId]; the viewer's own id leaves the project. Their open
  /// tasks there lose their assignee.
  Future<void> removeMember(TaskTab project, int userId);

  /// [division]'s live repeating tasks, soonest due first. Leads only
  /// (arcbyte decision 0012).
  Future<List<RepeatingSeries>> repeatingFor(TaskTab division);

  /// Every occurrence of a series, newest first.
  Future<List<Occurrence>> seriesHistory(int seriesId);

  /// Deletes the series' open task, and its rule with it, only while it is
  /// waiting; a started one fails with 409 and can only be stopped.
  Future<void> deleteSeries(int seriesId);
}

/// In-memory [TasksApi] seeded with the mockups' sample data, dated relative
/// to [today] so "today" and "overdue" always look right.
///
/// The viewer is Mira: owner of tasko-web (so she reviews there), a plain
/// member of tasko-app (so she can ask for extensions there), and a
/// supervisor of tech (so she can create projects and set up repeats). Membership rules match
/// Tasko-API's, refused with the same [ApiException] statuses.
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
  final _proofs = <int, Proof>{};
  final _tabs = [TaskTab.private, tech, taskoApp, taskoWeb];
  final _members = <TaskTab, List<Member>>{};

  /// What was sent, for tests to check.
  final reviews = <(int taskId, bool approve, String? reason)>[];
  final extensionRequests = <(int taskId, DateTime newDue, String reason)>[];

  static const tech = TaskTab(TabKind.division, 1, 'tech');
  static const taskoApp = TaskTab(TabKind.project, 1, 'tasko-app');
  static const taskoWeb = TaskTab(TabKind.project, 2, 'tasko-web');

  static const _me = User(id: 1, name: 'Mira', email: 'mira@arcbyte.dev');
  static const _ana = User(id: 2, name: 'Ana');
  static const _budi = User(id: 3, name: 'Budi');

  /// Everyone who can log in. Gita is in no project, to be added in tests.
  static const users = [
    _me,
    _ana,
    _budi,
    User(id: 4, name: 'Citra', email: 'citra@arcbyte.dev'),
    User(id: 5, name: 'Dimas', email: 'dimas@arcbyte.dev'),
    User(id: 6, name: 'Eka', email: 'eka@arcbyte.dev'),
    User(id: 7, name: 'Fajar', email: 'fajar@arcbyte.dev'),
    User(id: 8, name: 'Gita', email: 'gita@arcbyte.dev'),
  ];

  @override
  Future<User> me() async => _me;

  @override
  Future<List<TaskTab>> myTabs() async => [for (final t in _tabs) _mine(t)];

  @override
  Future<List<Task>> tasksFor(TaskTab tab) async => [
    for (final t in _tasks[tab] ?? <Task>[])
      if (t.parentId == null) t,
  ];

  @override
  Future<Task> setStatus(
    Task task,
    TaskStatus status, {
    String? proofUrl,
  }) async {
    if (proofUrl != null) {
      _proofs[task.id] = Proof(
        url: proofUrl,
        author: _me,
        createdAt: DateTime.now(),
      );
    }
    final done = _replace(
      task.copyWith(
        status: status,
        completedAt: () => status == TaskStatus.done ? DateTime.now() : null,
      ),
    );
    if (status == TaskStatus.done) _nextOccurrence(done);
    return _find(done.id, personal: done.personal);
  }

  /// As Tasko-API does (arcbyte decisions 0009, 0012): finishing a repeating
  /// task creates the next one, one step later, and the rule moves onto it.
  void _nextOccurrence(Task done) {
    final r = done.repeat, due = done.dueDate;
    if (r == null || due == null || r.count == 1) return;
    // ponytail: steps whole units and ignores weekdays; the server's nextDue is the real one.
    final next = switch (r.unit) {
      RepeatUnit.day => due.add(Duration(days: r.every)),
      RepeatUnit.week => due.add(Duration(days: 7 * r.every)),
      RepeatUnit.month => DateTime(
        due.year,
        due.month + r.every,
        due.day,
        due.hour,
        due.minute,
      ),
      RepeatUnit.year => DateTime(
        due.year + r.every,
        due.month,
        due.day,
        due.hour,
        due.minute,
      ),
    };
    final until = r.until;
    if (until != null && next.isAfter(until.add(const Duration(days: 1)))) {
      return;
    }
    _replace(done.copyWith(repeat: () => null));
    _add(
      _tabOf(done),
      Task(
        id: _nextId(),
        name: done.name,
        description: done.description,
        priority: done.priority,
        dueDate: next,
        assigneeId: done.assigneeId,
        requiredProofType: done.requiredProofType,
        status: TaskStatus.waiting,
        repeat: Repeat(
          every: r.every,
          unit: r.unit,
          weekdays: r.weekdays,
          until: r.until,
          count: r.count == null ? null : r.count! - 1,
        ),
        seriesId: done.seriesId,
      ),
      creator: _me,
    );
  }

  @override
  Future<List<Member>> membersOf(TaskTab tab) async {
    if (tab.kind != TabKind.private && _memberIn(tab, _me.id) == null) {
      _refuse(403, 'Not a member');
    }
    return [...?_members[tab]];
  }

  @override
  Future<Task> createTask(
    TaskTab tab, {
    required String name,
    String? description,
    required Priority priority,
    DateTime? dueDate,
    int? assigneeId,
    Repeat? repeat,
  }) async {
    final personal = tab.kind == TabKind.private;
    if (repeat != null && !canManageRepeats(_mine(tab))) {
      _refuse(403, 'Only a division admin or supervisor can set up a repeat');
    }
    final id = _nextId();
    return _add(
      tab,
      Task(
        id: id,
        name: name,
        description: description,
        priority: priority,
        dueDate: dueDate,
        assigneeId: personal ? null : assigneeId,
        status: personal ? TaskStatus.todo : TaskStatus.waiting,
        personal: personal,
        repeat: repeat,
        seriesId: repeat == null ? null : id,
      ),
      creator: _me,
    );
  }

  @override
  Future<Task> updateTask(Task task) async {
    final before = _find(task.id, personal: task.personal);
    if (!_sameRule(before.repeat, task.repeat) &&
        !canManageRepeats(_mine(_tabOf(task)))) {
      _refuse(403, 'Only a division admin or supervisor can set up a repeat');
    }
    // Turning a rule on starts a series, or continues the one it was in.
    return _replace(
      task.repeat == null
          ? task
          : task.copyWith(seriesId: before.seriesId ?? task.id),
    );
  }

  static bool _sameRule(Repeat? a, Repeat? b) =>
      a == b ||
      (a != null &&
          b != null &&
          a.every == b.every &&
          a.unit == b.unit &&
          a.until == b.until &&
          a.count == b.count &&
          a.weekdays.join() == b.weekdays.join());

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
      proof: team ? _proofs[task.id] : null,
      canReview: team && tab == taskoWeb,
      canArchive: team && _creatorOf[task.id] == _me.id,
      canRequestExtension: team && tab != taskoWeb && task.assigneeId == _me.id,
      canRepeat:
          tab.kind == TabKind.division &&
          task.parentId == null &&
          canManageRepeats(_mine(tab)),
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

  @override
  Future<TaskTab> createProject(
    int divisionId,
    String name, {
    String? description,
    DateTime? dueDate,
  }) async {
    final division = _tabs.firstWhere(
      (t) => t.kind == TabKind.division && t.id == divisionId,
      orElse: () => _refuse(403, 'Not a member'),
    );
    if (!canCreateProject(_mine(division))) {
      _refuse(403, 'Only a division admin or supervisor can create a project');
    }
    final id = _tabs.where((t) => t.kind == TabKind.project).length + 1;
    final tab = TaskTab(TabKind.project, id, name.trim());
    _tabs.add(tab);
    _tasks[tab] = [];
    _members[tab] = [const Member(_me, 'owner')];
    return _mine(tab);
  }

  @override
  Future<List<User>> searchUsers(String q) async {
    final needle = q.trim().toLowerCase();
    return [
      for (final u in users)
        if (u.name.toLowerCase().contains(needle) ||
            (u.email ?? '').toLowerCase().contains(needle))
          u,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<Member> addMember(
    TaskTab project,
    int userId, {
    String role = 'member',
  }) async {
    final mine = _mine(project);
    if (!canManageMembers(mine)) {
      _refuse(403, 'Only an owner or person-in-charge can add members');
    }
    if (role == 'owner' && mine.role != 'owner') _ownersOnly();
    final user = users.where((u) => u.id == userId).firstOrNull;
    if (user == null) _refuse(404, 'No such user');
    if (_memberIn(project, userId) != null) _refuse(409, 'Already a member');
    final m = Member(user, role);
    _members[project]!.add(m);
    return m;
  }

  @override
  Future<Member> setMemberRole(TaskTab project, int userId, String role) async {
    final mine = _mine(project);
    if (!canManageMembers(mine)) {
      _refuse(403, 'Only an owner or person-in-charge can change roles');
    }
    final current = _memberIn(project, userId) ?? _notMember();
    if ((role == 'owner' || current.role == 'owner') && mine.role != 'owner') {
      _ownersOnly();
    }
    if (current.role == 'owner' && role != 'owner') _keepAnOwner(project);
    final list = _members[project]!;
    return list[list.indexOf(current)] = Member(current.user, role);
  }

  @override
  Future<void> removeMember(TaskTab project, int userId) async {
    final mine = _mine(project);
    final self = userId == _me.id;
    if (!self && !canManageMembers(mine)) {
      _refuse(403, 'Only an owner or person-in-charge can remove members');
    }
    final current = _memberIn(project, userId) ?? _notMember();
    if (!self && current.role == 'owner' && mine.role != 'owner') _ownersOnly();
    if (current.role == 'owner') _keepAnOwner(project);
    _members[project]!.remove(current);
    // Open but not in review: review keeps its assignee (arcbyte decision 0010).
    final tasks = _tasks[project]!;
    for (final (i, t) in tasks.indexed) {
      if (t.assigneeId == userId &&
          t.status != TaskStatus.review &&
          isOpen(t)) {
        tasks[i] = t.copyWith(assigneeId: () => null);
      }
    }
    if (self) _tabs.remove(project);
  }

  @override
  Future<List<RepeatingSeries>> repeatingFor(TaskTab division) async {
    _assertLead(division);
    final all = _tasks[division] ?? <Task>[];
    final live = [
      for (final t in all)
        if (t.repeat != null && t.parentId == null) t,
    ]..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return [
      for (final t in live)
        RepeatingSeries(t, [
          for (final o in _occurrences(
            t.seriesId!,
          ).where((o) => o.onTime != null).take(5))
            o.onTime!,
        ]),
    ];
  }

  @override
  Future<List<Occurrence>> seriesHistory(int seriesId) async {
    final list = _occurrences(seriesId);
    if (list.isEmpty) _refuse(404, 'No such series');
    _assertLead(_tabOf(list.first.task));
    return list;
  }

  @override
  Future<void> deleteSeries(int seriesId) async {
    final open = _tasks.values
        .expand((l) => l)
        .where((t) => t.seriesId == seriesId && t.repeat != null)
        .firstOrNull;
    if (open == null) _refuse(404, 'No such repeating task');
    final tab = _tabOf(open);
    _assertLead(tab);
    if (open.status != TaskStatus.waiting) {
      _refuse(409, 'Already started — stop repeating instead');
    }
    _tasks[tab]!.remove(open);
  }

  /// A series, newest due first. Finished when it was ticked done: the fake
  /// keeps no review date.
  List<Occurrence> _occurrences(int seriesId) {
    final list = [
      for (final t in _tasks.values.expand((l) => l))
        if (t.seriesId == seriesId) t,
    ]..sort((a, b) => b.dueDate!.compareTo(a.dueDate!));
    return [
      for (final t in list)
        Occurrence(
          task: t,
          finishedAt: t.status == TaskStatus.done ? t.completedAt : null,
          onTime: t.status == TaskStatus.done
              ? !t.completedAt!.isAfter(t.dueDate!)
              : null,
          proofUrl: _proofs[t.id]?.url,
        ),
    ];
  }

  void _assertLead(TaskTab division) {
    if (!canManageRepeats(_mine(division))) {
      _refuse(403, 'Only a division admin or supervisor can see repeats');
    }
  }

  Task _find(int id, {bool personal = false}) => _tasks.values
      .expand((l) => l)
      .firstWhere((t) => t.id == id && t.personal == personal);

  /// [tab] with the viewer's role in it.
  TaskTab _mine(TaskTab tab) =>
      TaskTab(tab.kind, tab.id, tab.name, role: _memberIn(tab, _me.id)?.role);

  Member? _memberIn(TaskTab tab, int userId) =>
      _members[tab]?.where((m) => m.user.id == userId).firstOrNull;

  void _keepAnOwner(TaskTab project) {
    if (_members[project]!.where((m) => m.role == 'owner').length < 2) {
      _refuse(422, 'A project needs an owner');
    }
  }

  static Never _refuse(int status, String message) =>
      throw ApiException(status, message);
  static Never _ownersOnly() =>
      _refuse(403, 'Only an owner can make or remove an owner');
  static Never _notMember() => _refuse(404, 'Not a member of this project');

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
    List<Member> members(String mira, String ana) => [
      Member(_me, mira),
      Member(_ana, ana),
      for (final u in users.sublist(2, 7)) Member(u, 'member'),
    ];
    _members[tech] = members('supervisor', 'admin');
    _members[taskoApp] = members('member', 'person-in-charge');
    _members[taskoWeb] = members('owner', 'person-in-charge');
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
