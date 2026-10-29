/// `tasks.status` and `personal_tasks.status` in one enum. Personal tasks use
/// todo / inProgress / done; team tasks use waiting / inProgress / review /
/// done (arcbyte decision 0004).
enum TaskStatus {
  todo('to do'),
  waiting('waiting'),
  inProgress('in progress'),
  review('review'),
  done('done');

  const TaskStatus(this.label);
  final String label;
}

/// `priority_level`, 1..4.
enum Priority {
  low,
  medium,
  high,
  urgent;

  static Priority fromLevel(int level) => values[level.clamp(1, 4) - 1];

  int get level => index + 1;
}

enum RepeatUnit { day, week, month, year }

/// A workspace task's repeat rule (arcbyte decision 0009), as in Santian:
/// finishing the task makes the server create the next one, due one step
/// later, and the rule moves onto it.
class Repeat {
  const Repeat({
    this.every = 1,
    this.unit = RepeatUnit.week,
    this.weekdays = const [],
    this.until,
    this.count,
  });

  final int every;
  final RepeatUnit unit;

  /// ISO weekdays, 1 = Monday. Weekly only.
  final List<int> weekdays;

  /// The last day an occurrence may fall on.
  final DateTime? until;

  /// Occurrences left, this one included.
  final int? count;
}

/// One row in the list: a `tasks` row, or a `personal_tasks` row when
/// [personal] is true. Both tables map onto this one model so the list rules
/// work on either. Sub-tasks are Tasks with a [parentId].
class Task {
  const Task({
    required this.id,
    required this.name,
    required this.status,
    this.priority = Priority.medium,
    this.dueDate,
    this.description,
    this.assigneeId,
    this.requiredProofType,
    this.personal = false,
    this.code,
    this.parentId,
    this.completedAt,
    this.repeat,
    this.seriesId,
  });

  final int id;

  /// `tasks.name` or `personal_tasks.title`.
  final String name;
  final TaskStatus status;
  final Priority priority;
  final DateTime? dueDate;

  /// `tasks.description` or `personal_tasks.note`.
  final String? description;

  /// Team tasks only.
  final int? assigneeId;

  /// Set means ticking sends the task to review (arcbyte decision 0004).
  final String? requiredProofType;
  final bool personal;

  /// `tasks.code`, e.g. "TW-0042". Personal tasks have none.
  final String? code;
  final int? parentId;

  /// `completed_date` or `completed_at`.
  final DateTime? completedAt;

  /// Workspace tasks only.
  final Repeat? repeat;

  /// The first task's id, shared by every occurrence of a repeating task
  /// (arcbyte decision 0012). Null if it never repeated.
  final int? seriesId;

  Task copyWith({
    String? name,
    String? Function()? description,
    TaskStatus? status,
    Priority? priority,
    DateTime? dueDate,
    int? Function()? assigneeId,
    DateTime? Function()? completedAt,
    Repeat? Function()? repeat,
    int? Function()? seriesId,
  }) => Task(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    dueDate: dueDate ?? this.dueDate,
    description: description != null ? description() : this.description,
    assigneeId: assigneeId != null ? assigneeId() : this.assigneeId,
    requiredProofType: requiredProofType,
    personal: personal,
    code: code,
    parentId: parentId,
    completedAt: completedAt != null ? completedAt() : this.completedAt,
    repeat: repeat != null ? repeat() : this.repeat,
    seriesId: seriesId != null ? seriesId() : this.seriesId,
  );
}

/// One occurrence of a repeating task, and how it went. [onTime] is null
/// while it is open. It counts as finished when it was sent for review, or
/// else ticked done (arcbyte decision 0012).
class Occurrence {
  const Occurrence({
    required this.task,
    this.finishedAt,
    this.onTime,
    this.proofUrl,
  });

  final Task task;
  final DateTime? finishedAt;
  final bool? onTime;

  /// The latest proof's link.
  final String? proofUrl;
}

/// A repeating task set up in a division: its latest [task], its [rule], and
/// whether each of its last 5 finished occurrences was on time, newest first.
/// An [ended] one was stopped or ran out; it stays until a lead deletes it
/// (arcbyte decision 0013).
class RepeatingSeries {
  const RepeatingSeries(
    this.task,
    this.recent, {
    required this.rule,
    this.ended = false,
  });

  final Task task;
  final List<bool> recent;
  final Repeat rule;
  final bool ended;
}

/// [myTasks] is not a place: it gathers the user's tasks from the other
/// tabs (arcbyte decision 0017) and never goes to the API.
enum TabKind { myTasks, private, division, project }

/// A tab on the home screen: `private`, a division, or a project
/// (arcbyte decision 0002).
class TaskTab {
  const TaskTab(this.kind, this.id, this.name, {this.role});

  final TabKind kind;
  final int id;
  final String name;

  /// The viewer's `division_members.role_type` or `project_members.role`;
  /// null on `private`. Only decides which buttons show: the server checks
  /// every change. Not part of equality.
  final String? role;

  static const private = TaskTab(TabKind.private, 0, 'private');
  static const myTasks = TaskTab(TabKind.myTasks, 0, 'my tasks');

  @override
  bool operator ==(Object other) =>
      other is TaskTab && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

class User {
  const User({
    required this.id,
    required this.name,
    this.email,
    this.mustChangePassword = false,
  });

  final int id;
  final String name;

  /// `users.email`. Only loaded for the viewer.
  final String? email;

  /// Only loaded for the viewer. Not enforced until the server has a
  /// change-password route (arcbyte decision 0007).
  final bool mustChangePassword;
}

/// Someone who can be assigned a task in a tab: `project_members.role` or
/// `division_members.role_type`.
class Member {
  const Member(this.user, this.role);

  final User user;
  final String role;
}

/// A `comments` row on a team task.
class Comment {
  const Comment({
    required this.author,
    required this.body,
    required this.createdAt,
  });

  final User author;
  final String body;
  final DateTime createdAt;
}

/// A `proofs` row: a link sent with the tick to review (arcbyte decision
/// 0007).
class Proof {
  const Proof({
    required this.url,
    required this.author,
    required this.createdAt,
  });

  final String url;
  final User author;
  final DateTime createdAt;
}

/// What Task Detail shows beyond the row. The server decides the `can*`
/// flags from roles (arcbyte decision 0004), so the app does not repeat
/// those rules.
class TaskDetail {
  const TaskDetail({
    required this.tab,
    this.subtasks = const [],
    this.comments = const [],
    this.assignee,
    this.proof,
    this.canReview = false,
    this.canArchive = false,
    this.canRequestExtension = false,
    this.canRepeat = false,
    this.canViewLog = false,
  });

  /// The tab the task lives in.
  final TaskTab tab;
  final List<Task> subtasks;
  final List<Comment> comments;
  final User? assignee;

  /// The latest proof; an earlier one stays on the server after a rejection.
  final Proof? proof;

  /// The viewer is the project's person-in-charge or author, or the
  /// division's admin or supervisor.
  final bool canReview;

  /// The viewer created the task.
  final bool canArchive;

  /// The viewer is a member, not management.
  final bool canRequestExtension;

  /// A workspace's top-level task, and the viewer is one of its division's
  /// admins or supervisors (arcbyte decision 0012).
  final bool canRepeat;

  /// The viewer leads the task's tab: its division's admins and supervisors,
  /// or its project's owners and persons-in-charge (arcbyte decision 0014).
  final bool canViewLog;
}

/// Which activity log to open (arcbyte decision 0014). Only leads open one;
/// a user also opens their own.
sealed class ActivityScope {
  const ActivityScope();
}

/// One task's history; a sub-task's rows are on its parent.
final class TaskLog extends ActivityScope {
  const TaskLog(this.task);
  final Task task;
}

/// A project's rows, or a division's own tab plus its projects' project and
/// member rows.
final class TabLog extends ActivityScope {
  const TabLog(this.tab);
  final TaskTab tab;
}

/// What a user did, and what was done to them.
final class UserLog extends ActivityScope {
  const UserLog(this.user);
  final User user;
}

/// An `activity_logs` row. Names are as they were when it was written, so a
/// row still reads after its user or subject is deleted.
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.action,
    required this.actorName,
    required this.subject,
    required this.tab,
    required this.createdAt,
    this.actor,
    this.target,
    this.changes = const {},
  });

  final int id;

  /// `task.created`, `member.added`, …: the list is in arcbyte decision 0014.
  final String action;

  /// Null once the user is deleted; [actorName] stays.
  final User? actor;
  final String actorName;

  /// `type` is `task`, `project`, `member` or `series`.
  final ({String type, int id, String label}) subject;

  /// The person the action landed on.
  final User? target;

  /// Where it happened. Its name is empty once a project is deleted.
  final TaskTab tab;

  /// An edit is `{field: [before, after]}`; other actions carry their own keys.
  final Map<String, dynamic> changes;
  final DateTime createdAt;
}

/// A `notifications` row, with its text already written by the
/// server from `type` and `data`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.text,
    required this.createdAt,
    this.actor,
    this.readAt,
  });

  /// `notifications.id` is a uuid.
  final String id;
  final String text;
  final DateTime createdAt;

  /// Who caused it. Null for system messages (due soon, approvals).
  final User? actor;
  final DateTime? readAt;

  bool get unread => readAt == null;

  AppNotification markRead(DateTime at) => AppNotification(
    id: id,
    text: text,
    createdAt: createdAt,
    actor: actor,
    readAt: readAt ?? at,
  );
}
