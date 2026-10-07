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

/// Open tasks due on each day of [month], keyed by day of month
/// (arcbyte decision 0003).
Map<int, int> dueCounts(Iterable<Task> tasks, DateTime month) {
  final counts = <int, int>{};
  for (final t in tasks) {
    final due = t.dueDate;
    if (!isOpen(t) || due == null) continue;
    if (due.year != month.year || due.month != month.month) continue;
    counts.update(due.day, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

/// Thrown by [statusAfterTick] when a task needs a proof before review.
class ProofRequired implements Exception {
  const ProofRequired();
}

/// What ticking the checkbox sets (arcbyte decisions 0004 and 0005), or null
/// when the tap does nothing (a task in review waits on its reviewer).
TaskStatus? statusAfterTick(Task t) {
  if (t.status == TaskStatus.review) return null;
  if (t.status == TaskStatus.done) {
    return t.personal ? TaskStatus.todo : TaskStatus.waiting;
  }
  if (t.personal || t.requiredProofType == null) return TaskStatus.done;
  // ponytail: proof upload isn't built, so a proof is never attached yet.
  // Return TaskStatus.review here once Task Detail can attach one.
  throw const ProofRequired();
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
