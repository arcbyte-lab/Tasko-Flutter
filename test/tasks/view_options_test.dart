import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/view_options.dart';

Task t(
  int id,
  String name, {
  Priority priority = Priority.medium,
  TaskStatus status = TaskStatus.waiting,
  int? due,
  int? assignee,
}) => Task(
  id: id,
  name: name,
  priority: priority,
  status: status,
  dueDate: due == null ? null : DateTime(2026, 10, due),
  assigneeId: assignee,
);

void main() {
  final now = DateTime(2026, 10, 7, 10);
  final tasks = [
    t(1, 'bravo', priority: Priority.low, due: 9, assignee: 2),
    t(2, 'Alpha', priority: Priority.urgent, due: 5, assignee: 1),
    t(3, 'charlie', priority: Priority.high, assignee: null),
    t(
      4,
      'delta',
      priority: Priority.urgent,
      due: 7,
      assignee: 2,
      status: TaskStatus.inProgress,
    ),
  ];
  List<String> names(Iterable<Task> l) => [for (final x in l) x.name];
  const people = {1: 'me', 2: 'Ana'};

  test('defaults: by due date, no date last', () {
    expect(names(ViewOptions.defaults.sort(tasks)), [
      'Alpha',
      'delta',
      'bravo',
      'charlie',
    ]);
    expect(ViewOptions.defaults.isDefault, isTrue);
  });

  test('descending keeps no-date last', () {
    const v = ViewOptions(descending: true);
    expect(names(v.sort(tasks)), ['bravo', 'delta', 'Alpha', 'charlie']);
  });

  test('sort by title ignores case; by priority, low first', () {
    expect(names(const ViewOptions(sortBy: SortBy.title).sort(tasks)), [
      'Alpha',
      'bravo',
      'charlie',
      'delta',
    ]);
    expect(
      names(const ViewOptions(sortBy: SortBy.priority).sort(tasks)).first,
      'bravo',
    );
  });

  test('filters combine', () {
    const v = ViewOptions(priority: Priority.urgent, assigneeId: 2);
    expect(names(tasks.where(v.matches)), ['delta']);
    expect(v.withoutFilters().isDefault, isTrue);
  });

  test('group by priority: urgent first, empty groups skipped', () {
    final s = const ViewOptions(
      groupBy: GroupBy.priority,
    ).sections(tasks, now: now, names: people);
    expect(s.map((x) => x.label), ['URGENT', 'HIGH', 'LOW']);
    expect(names(s.first.tasks), ['Alpha', 'delta']);
  });

  test('group by due date flags overdue', () {
    final s = ViewOptions.defaults.sections(tasks, now: now, names: people);
    expect(s.map((x) => x.label), ['OVERDUE', 'TODAY', 'LATER', 'NO DATE']);
    expect(s.first.alert, isTrue);
  });

  test('group by assignee: me first, nobody last', () {
    final s = const ViewOptions(
      groupBy: GroupBy.assignee,
    ).sections(tasks, now: now, names: people);
    expect(s.map((x) => x.label), ['ME', 'ANA', 'NOBODY']);
  });

  test('group by none: one block with no header', () {
    final s = const ViewOptions(
      groupBy: GroupBy.none,
    ).sections(tasks, now: now, names: people);
    expect(s.single.label, isNull);
    expect(s.single.tasks, hasLength(4));
  });
}
