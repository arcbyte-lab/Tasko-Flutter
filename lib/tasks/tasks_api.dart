import 'models.dart';

/// What the app needs from the server. The only seam in the app: the fake
/// below runs everything until the Laravel API lands.
abstract interface class TasksApi {
  Future<User> me();

  /// `private`, then the user's divisions, then their projects.
  Future<List<TaskTab>> myTabs();

  /// A division tab holds only tasks with no project (arcbyte decision 0002).
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
}

/// In-memory [TasksApi] seeded with the mockups' sample data, dated relative
/// to [today] so "today" and "overdue" always look right.
class FakeTasksApi implements TasksApi {
  FakeTasksApi({required DateTime today, Map<TaskTab, List<Task>>? tasks})
    : _tasks = tasks ?? _seed(DateTime(today.year, today.month, today.day));

  final Map<TaskTab, List<Task>> _tasks;

  static const tech = TaskTab(TabKind.division, 1, 'tech');
  static const taskoApp = TaskTab(TabKind.project, 1, 'tasko-app');
  static const taskoWeb = TaskTab(TabKind.project, 2, 'tasko-web');

  @override
  Future<User> me() async => const User(id: 1, name: 'Mira');

  @override
  Future<List<TaskTab>> myTabs() async => [
    TaskTab.private,
    tech,
    taskoApp,
    taskoWeb,
  ];

  @override
  Future<List<Task>> tasksFor(TaskTab tab) async => [...?_tasks[tab]];

  @override
  Future<Task> setStatus(Task task, TaskStatus status) async {
    final updated = task.copyWith(status: status);
    for (final list in _tasks.values) {
      final i = list.indexWhere(
        (t) => t.id == task.id && t.personal == task.personal,
      );
      if (i != -1) list[i] = updated;
    }
    return updated;
  }

  @override
  Future<List<Member>> membersOf(TaskTab tab) async {
    if (tab.kind == TabKind.private) return [];
    final lead = tab.kind == TabKind.project ? 'person-in-charge' : 'admin';
    return [
      Member(await me(), 'member'),
      Member(const User(id: 2, name: 'Ana'), lead),
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
    final ids = _tasks.values.expand((l) => l).map((t) => t.id);
    final task = Task(
      id: ids.fold(0, (a, b) => a > b ? a : b) + 1,
      name: name,
      description: description,
      priority: priority,
      dueDate: dueDate,
      assigneeId: personal ? null : assigneeId,
      status: personal ? TaskStatus.todo : TaskStatus.waiting,
      personal: personal,
    );
    (_tasks[tab] ??= []).add(task);
    return task;
  }

  static Map<TaskTab, List<Task>> _seed(DateTime today) {
    DateTime day(int offset) => today.add(Duration(days: offset));
    var id = 0;
    Task t(
      String name,
      Priority priority,
      TaskStatus status,
      int? due, {
      String? proof,
    }) => Task(
      id: ++id,
      name: name,
      priority: priority,
      status: status,
      dueDate: due == null ? null : day(due),
      requiredProofType: proof,
    );
    Task p(String name, Priority priority, TaskStatus status, int? due) => Task(
      id: ++id,
      name: name,
      priority: priority,
      status: status,
      dueDate: due == null ? null : day(due),
      personal: true,
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

    return {
      TaskTab.private: [
        p('Renew passport', high, todo, 2),
        p('Book dentist', medium, inProgress, 0),
        p('Pay internet bill', urgent, todo, -2),
        p('Read Flutter release notes', low, todo, null),
        p('Buy groceries', medium, done, -1),
      ],
      tech: [],
      taskoApp: [
        t('Set up CI', high, inProgress, 1),
        t('Port theme tokens', medium, waiting, 3),
        t('Draft API contract', medium, waiting, 3),
        t('Pick an icon set', low, done, -3),
      ],
      taskoWeb: [
        t('Fix login redirect', urgent, inProgress, -4),
        t('Write onboarding copy', medium, waiting, 0),
        t('Review PR #42', high, review, 0, proof: 'image'),
        t('Deploy staging', high, waiting, 1),
        t('Upload release screenshots', medium, waiting, 2, proof: 'image'),
        t('Design empty state', low, waiting, 7),
        t('Fix navbar on mobile', high, inProgress, 7),
        t('QA checkout flow', medium, review, 7, proof: 'file'),
        t('Write release notes', medium, waiting, 7),
        t('Add 404 page', low, waiting, 7),
        t('Update favicon', low, inProgress, 13),
        t('Clean up old branches', low, waiting, null),
        t('Set up analytics', medium, done, -2),
        t('Fix footer links', low, done, -5),
        t('Compress hero images', low, done, -6),
      ],
    };
  }
}
