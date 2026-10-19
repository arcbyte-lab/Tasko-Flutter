import 'package:flutter_test/flutter_test.dart';
import 'package:tasko/tasks/http_tasks_api.dart';
import 'package:tasko/tasks/models.dart';
import 'package:tasko/tasks/tasks_api.dart';

/// The fake repeats tasks as Tasko-API does (0009, 0012), so the repeating
/// view's tests see real series.
void main() {
  late FakeTasksApi api;
  setUp(() => api = FakeTasksApi(today: DateTime(2026, 10, 14)));

  const tech = FakeTasksApi.tech;
  Matcher refused(int status) =>
      throwsA(isA<ApiException>().having((e) => e.status, 'status', status));

  /// A weekly task in tech for Mira, due at [due], already repeating.
  Future<Task> weekly(String name, DateTime due) async {
    final t = await api.createTask(
      tech,
      name: name,
      priority: Priority.medium,
      dueDate: due,
      assigneeId: 1,
    );
    return api.updateTask(t.copyWith(repeat: () => const Repeat()));
  }

  test('a rule starts a series; done creates the next one in it', () async {
    final first = await weekly('Backup check', DateTime(2030, 1, 7, 9));
    expect(first.seriesId, first.id);
    final done = await api.setStatus(first, TaskStatus.done);
    expect(done.repeat, isNull);
    final next = (await api.tasksFor(
      tech,
    )).singleWhere((t) => t.repeat != null);
    expect((next.seriesId, next.dueDate), (first.id, DateTime(2030, 1, 14, 9)));
  });

  test(
    'lists live series with how the last ones went, and their history',
    () async {
      final first = await weekly('Backup check', DateTime(2030, 1, 7, 9));
      await api.setStatus(first, TaskStatus.done); // years early: on time
      final second = (await api.tasksFor(
        tech,
      )).singleWhere((t) => t.repeat != null);
      final late = await weekly('Late report', DateTime(2020, 1, 6, 9));
      await api.setStatus(second, TaskStatus.done);
      await api.setStatus(late, TaskStatus.done); // years late

      final live = await api.repeatingFor(tech);
      expect(live.map((s) => s.task.name), ['Late report', 'Backup check']);
      expect(live.map((s) => s.recent), [
        [false],
        [true, true],
      ]);
      final history = await api.seriesHistory(first.id);
      expect(history.map((o) => o.onTime), [null, true, true]);
      await expectLater(api.repeatingFor(FakeTasksApi.taskoApp), refused(403));
      await expectLater(api.seriesHistory(999), refused(404));
    },
  );

  test(
    'delete removes a waiting open task; a started one is refused',
    () async {
      final first = await weekly('Backup check', DateTime(2030, 1, 7, 9));
      await api.deleteSeries(first.id);
      expect(await api.repeatingFor(tech), isEmpty);

      final other = await weekly('Report', DateTime(2030, 1, 7, 9));
      await api.setStatus(other, TaskStatus.inProgress);
      await expectLater(api.deleteSeries(other.id), refused(409));
    },
  );

  test('turning a rule off and on keeps the series', () async {
    final t = await weekly('Backup check', DateTime(2030, 1, 7, 9));
    final off = await api.updateTask(t.copyWith(repeat: () => null));
    final on = await api.updateTask(
      off.copyWith(repeat: () => const Repeat(every: 2)),
    );
    expect(on.seriesId, t.id);
  });
}
