import 'models.dart';

/// Waiting on the assignee: counted on the calendar, can be overdue
/// (arcbyte decision 0004). A task in review is waiting on the reviewer.
bool isOpen(Task t) => switch (t.status) {
  TaskStatus.todo || TaskStatus.waiting || TaskStatus.inProgress => true,
  TaskStatus.review || TaskStatus.done => false,
};

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Open, and due on a calendar day before today. The time part is ignored.
bool isOverdue(Task t, DateTime now) =>
    isOpen(t) &&
    t.dueDate != null &&
    dateOnly(t.dueDate!).isBefore(dateOnly(now));

/// By due date, no date last, ties by id.
int taskOrder(Task a, Task b) {
  final (da, db) = (a.dueDate, b.dueDate);
  if (da == null && db != null) return 1;
  if (da != null && db == null) return -1;
  final byDate = da == null ? 0 : da.compareTo(db!);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

enum DayGroup {
  overdue('OVERDUE'),
  today('TODAY'),
  tomorrow('TOMORROW'),
  later('LATER'),
  noDate('NO DATE');

  const DayGroup(this.label);
  final String label;
}

/// The list header a not-done task sits under. A past task in review is
/// not overdue, so it goes under today.
DayGroup dayGroup(Task t, DateTime now) {
  final due = t.dueDate;
  if (due == null) return DayGroup.noDate;
  if (isOverdue(t, now)) return DayGroup.overdue;
  final days = dateOnly(due).difference(dateOnly(now)).inDays;
  if (days <= 0) return DayGroup.today;
  if (days == 1) return DayGroup.tomorrow;
  return DayGroup.later;
}

/// The Monday of [d]'s week, at midnight.
DateTime mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - d.weekday + 1);

/// The week [month] folds to: the [selected] day's if it is in [month],
/// else [today]'s, else the month's first week. As its Monday.
DateTime foldWeek(DateTime month, DateTime? selected, DateTime today) {
  bool inMonth(DateTime? d) =>
      d != null && d.year == month.year && d.month == month.month;
  if (inMonth(selected)) return mondayOf(selected!);
  if (inMonth(today)) return mondayOf(today);
  return mondayOf(DateTime(month.year, month.month));
}

/// Open tasks by the calendar day they are due, each day in [taskOrder]
/// (arcbyte decisions 0003, 0016). Any day before today is overdue.
Map<DateTime, List<Task>> dueByDate(
  Iterable<Task> tasks, {
  bool Function(Task) counts = isOpen,
}) {
  final days = <DateTime, List<Task>>{};
  for (final t in tasks) {
    if (!counts(t) || t.dueDate == null) continue;
    days.putIfAbsent(dateOnly(t.dueDate!), () => []).add(t);
  }
  for (final list in days.values) {
    list.sort(taskOrder);
  }
  return days;
}

/// [dueByDate] for one [month], keyed by day of month.
Map<int, List<Task>> dueByDay(Iterable<Task> tasks, DateTime month) => {
  for (final MapEntry(key: d, :value) in dueByDate(tasks).entries)
    if (d.year == month.year && d.month == month.month) d.day: value,
};

/// How many open tasks are due on each day of [month].
Map<int, int> dueCounts(Iterable<Task> tasks, DateTime month) =>
    dueByDay(tasks, month).map((day, list) => MapEntry(day, list.length));

/// Dots under a calendar day: 1 for 1 open task, 2 for 2–3, 3 for 4 or more
/// (arcbyte decision 0016), the old heatmap's steps.
int dotCount(int count) => switch (count) {
  <= 0 => 0,
  1 => 1,
  2 || 3 => 2,
  _ => 3,
};

/// Thrown by [statusAfterTick] when a task needs a proof before review: ask
/// the user for a link, then tick again with it.
class ProofRequired implements Exception {
  const ProofRequired();
}

/// What ticking the checkbox sets (arcbyte decisions 0004 and 0005), or null
/// when the tap does nothing (a task in review waits on its reviewer). A task
/// that needs a proof goes to review with [proofUrl] (decision 0007).
TaskStatus? statusAfterTick(Task t, {String? proofUrl}) {
  if (t.status == TaskStatus.review) return null;
  if (t.status == TaskStatus.done) {
    return t.personal ? TaskStatus.todo : TaskStatus.waiting;
  }
  if (t.personal || t.requiredProofType == null) return TaskStatus.done;
  if (proofUrl == null) throw const ProofRequired();
  return TaskStatus.review;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Oct 3", or "Oct 3, 2027" outside [now]'s year.
String shortDate(DateTime d, DateTime now) {
  final s = '${_months[d.month - 1]} ${d.day}';
  return d.year == now.year ? s : '$s, ${d.year}';
}

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "every week on Mon and Thu", "every 2 days, 6 times", "every month,
/// until Oct 30".
String repeatSummary(Repeat r, DateTime now) {
  final unit = r.every == 1 ? r.unit.name : '${r.every} ${r.unit.name}s';
  final days = [for (final d in r.weekdays) weekdayShort[d - 1]];
  final on = days.isEmpty
      ? ''
      : days.length == 1
      ? ' on ${days.single}'
      : ' on ${days.sublist(0, days.length - 1).join(', ')} and ${days.last}';
  final ends = r.count != null
      ? ', ${r.count} ${r.count == 1 ? 'time' : 'times'}'
      : r.until != null
      ? ', until ${shortDate(r.until!, now)}'
      : '';
  return 'every $unit$on$ends';
}

/// The bar under Task Detail (arcbyte lofi ticket T9).
enum DetailAction {
  startWorking,
  markDone,
  submitProof,
  waitingForReview,
  review,
  done,
  none,
}

/// What the action bar offers [viewerId] on [t]. A reviewer who is also the
/// assignee may review their own task (arcbyte decision 0004).
DetailAction actionFor(
  Task t, {
  required int viewerId,
  required bool canReview,
}) {
  if (t.status == TaskStatus.done) return DetailAction.done;
  final mine = t.personal || t.assigneeId == viewerId;
  if (t.status == TaskStatus.review) {
    if (canReview) return DetailAction.review;
    return mine ? DetailAction.waitingForReview : DetailAction.none;
  }
  if (!mine) return DetailAction.none;
  if (t.status == TaskStatus.todo || t.status == TaskStatus.waiting) {
    return DetailAction.startWorking;
  }
  return t.requiredProofType == null
      ? DetailAction.markDone
      : DetailAction.submitProof;
}

/// "just now", "45m ago", "2h ago", "3d ago", then the short date.
String relativeTime(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return shortDate(then, now);
}

/// A notification's time: "5m ago" and "2h ago" today, then "yesterday",
/// then the short date.
String notificationTime(DateTime then, DateTime now) {
  final days = dateOnly(now).difference(dateOnly(then)).inDays;
  if (days == 0) {
    final d = now.difference(then);
    return d.inHours < 1 ? '${d.inMinutes}m ago' : '${d.inHours}h ago';
  }
  if (days == 1) return 'yesterday';
  return shortDate(then, now);
}

/// The viewer may create a project in [tab]: a division they are an admin
/// or supervisor of (arcbyte decision 0010).
bool canCreateProject(TaskTab tab) =>
    tab.kind == TabKind.division &&
    (tab.role == 'admin' || tab.role == 'supervisor');

/// The viewer may add, re-role and remove members of [tab]: a project they
/// own or are the person-in-charge of (arcbyte decision 0010).
bool canManageMembers(TaskTab tab) =>
    tab.kind == TabKind.project &&
    (tab.role == 'owner' || tab.role == 'person-in-charge');

/// The viewer may see and set up [tab]'s repeating tasks: the same division
/// admins and supervisors who create projects (arcbyte decision 0012).
bool canManageRepeats(TaskTab tab) => canCreateProject(tab);

/// The viewer may open [tab]'s activity log: a division's admins and
/// supervisors (arcbyte decision 0014).
bool canViewDivisionLog(TaskTab tab) => canCreateProject(tab);

/// The viewer may open [tab]'s activity log: a project's owners and
/// persons-in-charge. Leading its division is not enough (decision 0014).
bool canViewProjectLog(TaskTab tab) => canManageMembers(tab);

/// The viewer reviews tasks in [tab] (arcbyte decision 0004): a division's
/// admins and supervisors, a project's owner and person-in-charge.
bool canReview(TaskTab tab) => canCreateProject(tab) || canManageMembers(tab);

/// [t], which lives in [tab], shows in "my tasks" for user [meId]
/// (decision 0017): every personal task, team tasks assigned to them, and
/// tasks waiting for their review.
bool isMine(Task t, TaskTab tab, int meId) =>
    tab.kind == TabKind.private ||
    t.assigneeId == meId ||
    (t.status == TaskStatus.review && canReview(tab));

/// What the calendar counts in "my tasks": open tasks, and reviews, which
/// are open for their reviewer.
bool isOpenOrReview(Task t) => isOpen(t) || t.status == TaskStatus.review;
