import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'tasks_api.dart';

class CreateTaskState {
  const CreateTaskState({
    this.name = '',
    this.note = '',
    this.priority = Priority.medium,
    this.dueDate,
    this.members = const [],
    this.assignee,
    this.submitting = false,
  });

  final String name;
  final String note;
  final Priority priority;
  final DateTime? dueDate;

  /// Empty in `private`: personal tasks have no assignee.
  final List<Member> members;

  /// Defaults to the current user, the first member.
  final Member? assignee;
  final bool submitting;

  bool get canSubmit => name.trim().isNotEmpty && !submitting;

  CreateTaskState copyWith({
    String? name,
    String? note,
    Priority? priority,
    DateTime? dueDate,
    List<Member>? members,
    Member? assignee,
    bool? submitting,
  }) => CreateTaskState(
    name: name ?? this.name,
    note: note ?? this.note,
    priority: priority ?? this.priority,
    dueDate: dueDate ?? this.dueDate,
    members: members ?? this.members,
    assignee: assignee ?? this.assignee,
    submitting: submitting ?? this.submitting,
  );
}

/// The draft behind the create sheet. Submits once.
class CreateTaskCubit extends Cubit<CreateTaskState> {
  CreateTaskCubit(this._api, this.tab) : super(const CreateTaskState());

  final TasksApi _api;
  final TaskTab tab;

  bool get isTeam => tab.kind != TabKind.private;

  Future<void> load() async {
    if (!isTeam) return;
    final members = await _api.membersOf(tab);
    emit(
      state.copyWith(
        members: members,
        assignee: members.isEmpty ? null : members.first,
      ),
    );
  }

  void setName(String v) => emit(state.copyWith(name: v));
  void setNote(String v) => emit(state.copyWith(note: v));
  void setPriority(Priority v) => emit(state.copyWith(priority: v));
  void setDueDate(DateTime v) => emit(state.copyWith(dueDate: v));
  void setAssignee(Member v) => emit(state.copyWith(assignee: v));

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
    );
  }
}
