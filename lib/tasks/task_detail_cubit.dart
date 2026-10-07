import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'task_rules.dart';
import 'tasks_api.dart';

class TaskDetailState {
  const TaskDetailState({required this.task, this.detail, this.me});

  final Task task;

  /// Null until loaded.
  final TaskDetail? detail;
  final User? me;

  bool get loading => detail == null;

  DetailAction get action => me == null || detail == null
      ? DetailAction.none
      : actionFor(task, viewerId: me!.id, canReview: detail!.canReview);

  TaskDetailState copyWith({Task? task, TaskDetail? detail, User? me}) =>
      TaskDetailState(
        task: task ?? this.task,
        detail: detail ?? this.detail,
        me: me ?? this.me,
      );
}

/// One task's detail. Every edit saves at once.
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

  String? _draftName;
  String? _draftNote;

  /// Typing in the title or note keeps a draft; [flush] saves it.
  void editName(String v) => _draftName = v;
  void editNote(String v) => _draftNote = v;

  /// Saves pending title and note drafts. Runs on blur and once more after
  /// the sheet closes, before the list reloads.
  Future<void> flush() async {
    final (name, note) = (_draftName, _draftNote);
    _draftName = _draftNote = null;
    if (name != null) await rename(name);
    if (note != null) await setNote(note);
  }

  /// Blank names are ignored; the old name stays.
  Future<void> rename(String name) async {
    final v = name.trim();
    if (v.isEmpty || v == state.task.name) return;
    await _save(state.task.copyWith(name: v));
  }

  Future<void> setNote(String note) async {
    final v = note.trim();
    if (v == (state.task.description ?? '')) return;
    await _save(state.task.copyWith(description: () => v.isEmpty ? null : v));
  }

  Future<void> setPriority(Priority p) =>
      _save(state.task.copyWith(priority: p));

  Future<void> setDueDate(DateTime d) => _save(state.task.copyWith(dueDate: d));

  Future<void> setAssignee(Member m) =>
      _save(state.task.copyWith(assigneeId: m.user.id));

  Future<void> startWorking() => _status(TaskStatus.inProgress);

  Future<void> markDone() => _status(TaskStatus.done);

  Future<void> _status(TaskStatus s) async {
    emit(state.copyWith(task: await _api.setStatus(state.task, s)));
  }

  Future<void> approve() async {
    emit(state.copyWith(task: await _api.review(state.task, approve: true)));
  }

  Future<void> decline(String reason) async {
    emit(
      state.copyWith(
        task: await _api.review(state.task, approve: false, reason: reason),
      ),
    );
  }

  Future<void> requestExtension(DateTime newDue, String reason) =>
      _api.requestExtension(state.task, newDue, reason);

  /// Throws [ProofRequired] like the list's checkbox.
  Future<void> tickSubtask(Task sub) async {
    final next = statusAfterTick(sub);
    if (next == null) return;
    await _api.setStatus(sub, next);
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
