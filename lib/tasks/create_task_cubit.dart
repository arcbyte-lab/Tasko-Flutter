import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'tasks_api.dart';

class CreateTaskState {
  const CreateTaskState({
    required this.tab,
    this.name = '',
    this.note = '',
    this.priority = Priority.medium,
    this.dueDate,
    this.members = const [],
    this.assignee,
    this.repeat,
    this.submitting = false,
  });

  /// Where the task is created. Changeable from "my tasks" (decision 0017).
  final TaskTab tab;
  final String name;
  final String note;
  final Priority priority;
  final DateTime? dueDate;

  /// Empty in `private`: personal tasks have no assignee.
  final List<Member> members;

  /// Defaults to the current user, the first member.
  final Member? assignee;

  /// Division leads only (arcbyte decision 0012).
  final Repeat? repeat;
  final bool submitting;

  /// A repeating task needs a due date: the rule steps from it.
  bool get missingDue => repeat != null && dueDate == null;

  bool get canSubmit => name.trim().isNotEmpty && !submitting && !missingDue;

  CreateTaskState copyWith({
    TaskTab? tab,
    String? name,
    String? note,
    Priority? priority,
    DateTime? dueDate,
    List<Member>? members,
    Member? Function()? assignee,
    Repeat? Function()? repeat,
    bool? submitting,
  }) => CreateTaskState(
    tab: tab ?? this.tab,
    name: name ?? this.name,
    note: note ?? this.note,
    priority: priority ?? this.priority,
    dueDate: dueDate ?? this.dueDate,
    members: members ?? this.members,
    assignee: assignee != null ? assignee() : this.assignee,
    repeat: repeat != null ? repeat() : this.repeat,
    submitting: submitting ?? this.submitting,
  );
}

/// The draft behind the create sheet. Submits once.
class CreateTaskCubit extends Cubit<CreateTaskState> {
  CreateTaskCubit(this._api, TaskTab tab) : super(CreateTaskState(tab: tab));

  final TasksApi _api;

  TaskTab get tab => state.tab;
  bool get isTeam => tab.kind != TabKind.private;

  Future<void> load() async {
    if (!isTeam) return;
    final tab = this.tab;
    final members = await _api.membersOf(tab);
    // Another tab may have been picked while these loaded.
    if (isClosed || this.tab != tab) return;
    emit(state.copyWith(members: members, assignee: () => members.firstOrNull));
  }

  /// Moves the draft to [tab] (from "my tasks"). Assignee and repeat belong
  /// to the old tab, so they go; a team tab loads its members again.
  Future<void> setTab(TaskTab tab) async {
    if (tab == this.tab) return;
    emit(
      state.copyWith(
        tab: tab,
        members: const [],
        assignee: () => null,
        repeat: () => null,
      ),
    );
    await load();
  }

  void setName(String v) => emit(state.copyWith(name: v));
  void setNote(String v) => emit(state.copyWith(note: v));
  void setPriority(Priority v) => emit(state.copyWith(priority: v));
  void setDueDate(DateTime v) => emit(state.copyWith(dueDate: v));
  void setAssignee(Member v) => emit(state.copyWith(assignee: () => v));

  /// Null stops it repeating.
  void setRepeat(Repeat? v) => emit(state.copyWith(repeat: () => v));

  /// Null when the title is blank. A blank note is stored as null.
  Future<Task?> submit() async {
    if (!state.canSubmit) return null;
    emit(state.copyWith(submitting: true));
    final note = state.note.trim();
    return _api.createTask(
      tab,
      name: state.name.trim(),
      description: note.isEmpty ? null : note,
      priority: state.priority,
      dueDate: state.dueDate,
      assigneeId: state.assignee?.user.id,
      repeat: state.repeat,
    );
  }
}
