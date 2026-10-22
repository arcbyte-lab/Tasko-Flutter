import 'http_tasks_api.dart' show repeatFromJson;
import 'models.dart';
import 'task_rules.dart';

/// One line for an activity log row (arcbyte decision 0014), built here from
/// `action` and `changes` so the wording can change without touching old
/// rows. In a task's own log the task goes unnamed ("Budi started it");
/// elsewhere it is named. In a project's own log the project goes unnamed.
String sentence(ActivityEntry e, ActivityScope scope, DateTime now) {
  final who = e.actorName;
  final c = e.changes;
  final inTask = scope is TaskLog;
  final it = inTask ? 'it' : e.subject.label;
  final of = inTask ? '' : ' of ${e.subject.label}';
  final on = inTask ? '' : ' on ${e.subject.label}';
  final inProject = scope is TabLog && scope.tab.kind == TabKind.project;
  String where(String word) => inProject ? '' : ' $word ${e.tab.name}';

  String day(Object? iso) => iso == null
      ? 'none'
      : shortDate(DateTime.parse(iso as String).toLocal(), now);
  String rule(Object? json) =>
      json == null ? 'none' : repeatSummary(repeatFromJson(json), now);
  String priority(Object? level) => Priority.fromLevel(level as int).name;
  List<dynamic> pair(String key) => c[key] as List<dynamic>;
  String unassigned() {
    final n = (c['unassignedTaskIds'] as List<dynamic>? ?? const []).length;
    return n == 0 ? '' : '; $n ${n == 1 ? 'task' : 'tasks'} unassigned';
  }

  // A row whose changes aren't the shape expected reads as its action.
  final fallback = '$who: ${e.action}';
  try {
    return switch (e.action) {
      'task.created' => '$who created $it',
      'task.renamed' => '$who renamed ${pair('name')[0]} to ${pair('name')[1]}',
      'task.description_changed' => '$who edited the description$of',
      'task.priority_changed' =>
        '$who changed the priority$of: ${priority(pair('priority')[0])} → ${priority(pair('priority')[1])}',
      'task.due_changed' =>
        '$who moved the due date$of: ${day(pair('dueDate')[0])} → ${day(pair('dueDate')[1])}',
      'task.assigned' => '$who assigned $it to ${c['assigneeName']}',
      'task.unassigned' =>
        '$who unassigned ${c['assigneeName']}${inTask ? '' : ' from ${e.subject.label}'}',
      'subtask.added' =>
        '$who added the sub-task ${c['subtask']}${inTask ? '' : ' to ${e.subject.label}'}',
      'task.started' => '$who started $it',
      'task.completed' => '$who marked $it done',
      'task.sent_to_review' => '$who sent $it to review',
      'task.reopened' => '$who reopened $it',
      'task.approved' => '$who approved $it',
      'task.rejected' =>
        '$who rejected $it${c['reason'] == null ? '' : ': ${c['reason']}'}',
      'comment.added' => '$who commented$on: ${c['body']}',
      'deadline.requested' =>
        '$who asked for more time$on: ${day(pair('dueDate')[0])} → ${day(pair('dueDate')[1])}, ${c['reason']}',
      'repeat.set' => '$who made $it repeat ${rule(pair('repeat')[1])}',
      'repeat.changed' =>
        '$who changed the repeat$of to ${rule(pair('repeat')[1])}',
      'repeat.stopped' => '$who stopped $it repeating',
      'repeat.next_created' =>
        '${inTask ? 'Created as the next repeat' : 'Next ${e.subject.label} created'}, due ${day(c['dueDate'])}',
      'series.deleted' => '$who deleted the repeat ${e.subject.label}',
      'project.created' => '$who created the project ${e.subject.label}',
      'member.added' =>
        '$who added ${e.subject.label}${where('to')} as ${c['role']}',
      'member.role_changed' =>
        '$who made ${e.subject.label} ${pair('role')[1]}${where('in')}',
      'member.removed' =>
        '$who removed ${e.subject.label}${where('from')}${unassigned()}',
      'member.left' =>
        '$who left ${inProject ? 'the project' : e.tab.name}${unassigned()}',
      _ => fallback,
    };
  } catch (_) {
    return fallback;
  }
}
