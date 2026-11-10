import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'task_rules.dart';
import 'tasks_api.dart';

class TaskDetailState {
  const TaskDetailState({
    required this.task,
    this.detail,
    this.me,
    this.draft,
    this.draftAssignee,
  });

  final Task task;

  /// Edit mode: the task with the changes so far; null when not editing.
  /// Nothing reaches the server until [TaskDetailCubit.save].
  final Task? draft;

  /// The user [draft]'s assignee, for the name on the row.
  final User? draftAssignee;
  bool get editing => draft != null;

  /// Null until loaded.
  final TaskDetail? detail;
  final User? me;

  bool get loading => detail == null;

  DetailAction get action => me == null || detail == null
      ? DetailAction.none
      : actionFor(task, viewerId: me!.id, canReview: detail!.canReview);

  TaskDetailState copyWith({
    Task? task,
    TaskDetail? detail,
    User? me,
    Task? Function()? draft,
    User? Function()? draftAssignee,
  }) => TaskDetailState(
    task: task ?? this.task,
    detail: detail ?? this.detail,
    me: me ?? this.me,
    draft: draft != null ? draft() : this.draft,
    draftAssignee: draftAssignee != null ? draftAssignee() : this.draftAssignee,
  );
}

/// One task's detail. Title, note, priority, due date and assignee change in
/// edit mode and save together (arcbyte decision 0018).
class TaskDetailCubit extends Cubit<TaskDetailState> {
  TaskDetailCubit(this._api, Task task) : super(TaskDetailState(task: task));

  final TasksApi _api;

  /// A save started as the sheet closes may land after the cubit is closed.
  @override
  void emit(TaskDetailState state) {
    if (!isClosed) super.emit(state);
  }

  Future<void> load() async {
    final me = await _api.me();
    emit(state.copyWith(me: me, detail: await _api.detail(state.task)));
  }

  Future<void> _save(Task t) async {
    emit(state.copyWith(task: t));
    await _api.updateTask(t);
    await load(); // the assignee shown may have changed
  }

  void startEdit() => emit(
    state.copyWith(
      draft: () => state.task,
      draftAssignee: () => state.detail?.assignee,
    ),
  );

  void cancelEdit() =>
      emit(state.copyWith(draft: () => null, draftAssignee: () => null));

  void _draft(Task Function(Task) change) {
    final d = state.draft;
    if (d != null) emit(state.copyWith(draft: () => change(d)));
  }

  void editName(String v) => _draft((d) => d.copyWith(name: v));
  void editNote(String v) => _draft((d) => d.copyWith(description: () => v));
  void setPriority(Priority p) => _draft((d) => d.copyWith(priority: p));
  void setDueDate(DateTime v) => _draft((d) => d.copyWith(dueDate: v));

  void setAssignee(Member m) {
    _draft((d) => d.copyWith(assigneeId: () => m.user.id));
    emit(state.copyWith(draftAssignee: () => m.user));
  }

  /// Sends the draft in one update, trimmed. A blank title keeps the old one;
  /// a blank note is saved as none. Leaves edit mode.
  Future<void> save() async {
    final d = state.draft;
    if (d == null) return;
    final name = d.name.trim();
    final note = (d.description ?? '').trim();
    final t = d.copyWith(
      name: name.isEmpty ? state.task.name : name,
      description: () => note.isEmpty ? null : note,
    );
    emit(state.copyWith(draft: () => null, draftAssignee: () => null, task: t));
    await _api.updateTask(t);
    await load(); // the assignee shown may have changed
  }

  /// Null stops it repeating.
  Future<void> setRepeat(Repeat? r) =>
      _save(state.task.copyWith(repeat: () => r));

  Future<void> startWorking() => _status(TaskStatus.inProgress);

  Future<void> markDone() => _status(TaskStatus.done);

  Future<void> _status(TaskStatus s, {String? proofUrl}) async {
    emit(
      state.copyWith(
        task: await _api.setStatus(state.task, s, proofUrl: proofUrl),
      ),
    );
  }

  /// Sends the task to review with a proof link (arcbyte decision 0007).
  Future<void> submitProof(String url) async {
    await _status(TaskStatus.review, proofUrl: url);
    await load(); // shows the proof
  }

  Future<void> approve() async {
    emit(state.copyWith(task: await _api.review(state.task, approve: true)));
  }

  Future<void> reject(String reason) async {
    emit(
      state.copyWith(
        task: await _api.review(state.task, approve: false, reason: reason),
      ),
    );
  }

  Future<void> requestExtension(DateTime newDue, String reason) async {
    await _api.requestExtension(state.task, newDue, reason);
    await load();
  }

  Future<void> archive() => _api.archiveTask(state.task);

  /// Throws [ProofRequired] like the list's checkbox.
  Future<void> tickSubtask(Task sub, {String? proofUrl}) async {
    final next = statusAfterTick(sub, proofUrl: proofUrl);
    if (next == null) return;
    await _api.setStatus(sub, next, proofUrl: proofUrl);
    await load();
  }

  Future<void> addSubtask(String name) async {
    final v = name.trim();
    if (v.isEmpty) return;
    await _api.createSubtask(state.task, v);
    await load();
  }

  Future<void> addComment(String body) async {
    final v = body.trim();
    if (v.isEmpty) return;
    await _api.addComment(state.task, v);
    await load();
  }
}
