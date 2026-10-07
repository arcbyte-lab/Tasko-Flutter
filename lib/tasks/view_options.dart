import 'models.dart';
import 'task_rules.dart';

enum GroupBy {
  dueDate('due date'),
  priority('priority'),
  status('status'),
  assignee('assignee'),
  none('none');

  const GroupBy(this.label);
  final String label;
}

enum SortBy {
  dueDate('due date'),
  priority('priority'),
  title('title'),
  created('created');

  const SortBy(this.label);
  final String label;
}

/// One block of the list: a header (null for none) and its rows.
typedef Section = ({String? label, bool alert, List<Task> tasks});

/// Group, sort and filter for the task list (arcbyte lofi ticket T5).
class ViewOptions {
  const ViewOptions({
    this.groupBy = GroupBy.dueDate,
    this.sortBy = SortBy.dueDate,
    this.descending = false,
    this.priority,
    this.status,
    this.assigneeId,
  });

  final GroupBy groupBy;
  final SortBy sortBy;
  final bool descending;

  /// Filters; null means any.
  final Priority? priority;
  final TaskStatus? status;
  final int? assigneeId;

  static const defaults = ViewOptions();

  bool get isDefault =>
      groupBy == GroupBy.dueDate &&
      sortBy == SortBy.dueDate &&
      !descending &&
      priority == null &&
      status == null &&
      assigneeId == null;

  /// Filters depend on the tab (its members, its statuses), so a tab switch
  /// drops them and keeps group and sort.
  ViewOptions withoutFilters() =>
      ViewOptions(groupBy: groupBy, sortBy: sortBy, descending: descending);

  ViewOptions copyWith({
    GroupBy? groupBy,
    SortBy? sortBy,
    bool? descending,
    Priority? Function()? priority,
    TaskStatus? Function()? status,
    int? Function()? assigneeId,
  }) => ViewOptions(
    groupBy: groupBy ?? this.groupBy,
    sortBy: sortBy ?? this.sortBy,
    descending: descending ?? this.descending,
    priority: priority != null ? priority() : this.priority,
    status: status != null ? status() : this.status,
    assigneeId: assigneeId != null ? assigneeId() : this.assigneeId,
  );

  bool matches(Task t) =>
      (priority == null || t.priority == priority) &&
      (status == null || t.status == status) &&
      (assigneeId == null || t.assigneeId == assigneeId);

  /// Sorted by [sortBy] in the chosen direction. Tasks with no due date stay
  /// last either way; ties fall back to [taskOrder].
  List<Task> sort(Iterable<Task> tasks) {
    int byKey(Task a, Task b) => switch (sortBy) {
      SortBy.dueDate => _byDue(a, b),
      SortBy.priority => a.priority.index.compareTo(b.priority.index),
      SortBy.title => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      // ponytail: ids grow with creation, so they stand in for created_at
      // until the model carries it.
      SortBy.created => a.id.compareTo(b.id),
    };
    return tasks.toList()..sort((a, b) {
      if (sortBy == SortBy.dueDate) {
        if (a.dueDate == null && b.dueDate != null) return 1;
        if (a.dueDate != null && b.dueDate == null) return -1;
      }
      final c = descending ? byKey(b, a) : byKey(a, b);
      return c != 0 ? c : taskOrder(a, b);
    });
  }

  static int _byDue(Task a, Task b) => a.dueDate == null || b.dueDate == null
      ? 0
      : a.dueDate!.compareTo(b.dueDate!);

  /// [tasks] (already filtered) split into headed sections, each sorted.
  /// [names] maps assignee ids to display names ("me" for the viewer).
  List<Section> sections(
    List<Task> tasks, {
    required DateTime now,
    required Map<int, String> names,
  }) {
    if (groupBy == GroupBy.none) {
      return [(label: null, alert: false, tasks: sort(tasks))];
    }
    final groups = <Object?, List<Task>>{};
    Object? keyOf(Task t) => switch (groupBy) {
      GroupBy.dueDate => dayGroup(t, now),
      GroupBy.priority => t.priority,
      GroupBy.status => t.status,
      GroupBy.assignee => t.assigneeId,
      GroupBy.none => null,
    };
    for (final t in tasks) {
      (groups[keyOf(t)] ??= []).add(t);
    }
    final Iterable<Object?> keys = switch (groupBy) {
      GroupBy.dueDate => DayGroup.values,
      GroupBy.priority => Priority.values.reversed, // urgent first
      GroupBy.status => TaskStatus.values,
      // The viewer ("me") first, then by name, nobody last.
      GroupBy.assignee =>
        groups.keys.toList()..sort((a, b) {
          if (a == null || b == null) return a == null ? 1 : -1;
          final (na, nb) = (names[a] ?? '', names[b] ?? '');
          if (na == 'me' || nb == 'me') return na == 'me' ? -1 : 1;
          return na.compareTo(nb);
        }),
      GroupBy.none => const [],
    };
    return [
      for (final k in keys)
        if (groups[k] case final rows?)
          (
            label: switch (k) {
              DayGroup g => g.label,
              Priority p => p.name.toUpperCase(),
              TaskStatus s => s.label.toUpperCase(),
              int id => (names[id] ?? 'someone').toUpperCase(),
              _ => 'NOBODY',
            },
            alert: k == DayGroup.overdue,
            tasks: sort(rows),
          ),
    ];
  }
}
