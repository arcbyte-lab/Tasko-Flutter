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

  Task copyWith({
    String? name,
    String? Function()? description,
    TaskStatus? status,
    Priority? priority,
    DateTime? dueDate,
    int? assigneeId,
    DateTime? Function()? completedAt,
  }) => Task(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    dueDate: dueDate ?? this.dueDate,
    description: description != null ? description() : this.description,
    assigneeId: assigneeId ?? this.assigneeId,
    requiredProofType: requiredProofType,
    personal: personal,
    code: code,
    parentId: parentId,
    completedAt: completedAt != null ? completedAt() : this.completedAt,
  );
}

enum TabKind { private, division, project }

/// A tab on the home screen: `private`, a division, or a project
/// (arcbyte decision 0002).
class TaskTab {
  const TaskTab(this.kind, this.id, this.name);

  final TabKind kind;
  final int id;
  final String name;

  static const private = TaskTab(TabKind.private, 0, 'private');

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
