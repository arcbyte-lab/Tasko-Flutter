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

/// `priority_level`, 1..4, as the Laravel app's TaskPriority enum.
enum Priority {
  low,
  medium,
  high,
  urgent;

  static Priority fromLevel(int level) => values[level.clamp(1, 4) - 1];
}

/// One row in the list: a `tasks` row, or a `personal_tasks` row when
/// [personal] is true. Both tables map onto this one model so the list rules
/// work on either.
class Task {
  const Task({
    required this.id,
    required this.name,
    required this.status,
    this.priority = Priority.medium,
    this.dueDate,
    this.requiredProofType,
    this.personal = false,
  });

  final int id;

  /// `tasks.name` or `personal_tasks.title`.
  final String name;
  final TaskStatus status;
  final Priority priority;
  final DateTime? dueDate;

  /// Set means ticking sends the task to review (arcbyte decision 0004).
  final String? requiredProofType;
  final bool personal;

  Task copyWith({TaskStatus? status}) => Task(
    id: id,
    name: name,
    status: status ?? this.status,
    priority: priority,
    dueDate: dueDate,
    requiredProofType: requiredProofType,
    personal: personal,
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
  const User({required this.id, required this.name});

  final int id;
  final String name;
}
