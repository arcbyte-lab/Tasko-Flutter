import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'task_rules.dart';
import 'tasks_api.dart';

class HomeState {
  const HomeState({
    required this.today,
    required this.month,
    this.user,
    this.tabs = const [],
    this.activeTab,
    this.tasks = const [],
    this.selectedDay,
    this.showCompleted = false,
  });

  /// Midnight of the current day; the cubit reads the clock once per load.
  final DateTime today;

  /// The first of the month the calendar shows.
  final DateTime month;
  final User? user;
  final List<TaskTab> tabs;
  final TaskTab? activeTab;

  /// Every task in [activeTab], unfiltered.
  final List<Task> tasks;
  final DateTime? selectedDay;
  final bool showCompleted;

  bool get loading => user == null;

  bool _inDay(Task t) =>
      selectedDay == null ||
      (t.dueDate != null && isSameDay(t.dueDate!, selectedDay!));

  /// Not done, sorted, narrowed to [selectedDay].
  List<Task> get listed =>
      tasks.where((t) => t.status != TaskStatus.done && _inDay(t)).toList()
        ..sort(taskOrder);

  List<Task> get completed =>
      tasks.where((t) => t.status == TaskStatus.done && _inDay(t)).toList()
        ..sort(taskOrder);

  Map<int, int> get dueCountsThisMonth => dueCounts(tasks, month);

  /// Days of [month] that have an overdue task, for the dot under the cell.
  Set<int> get overdueDays => {
    for (final t in tasks)
      if (isOverdue(t, today) &&
          t.dueDate!.year == month.year &&
          t.dueDate!.month == month.month)
        t.dueDate!.day,
  };

  HomeState copyWith({
    DateTime? month,
    User? user,
    List<TaskTab>? tabs,
    TaskTab? activeTab,
    List<Task>? tasks,
    DateTime? Function()? selectedDay,
    bool? showCompleted,
  }) => HomeState(
    today: today,
    month: month ?? this.month,
    user: user ?? this.user,
    tabs: tabs ?? this.tabs,
    activeTab: activeTab ?? this.activeTab,
    tasks: tasks ?? this.tasks,
    selectedDay: selectedDay != null ? selectedDay() : this.selectedDay,
    showCompleted: showCompleted ?? this.showCompleted,
  );
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._api, {DateTime Function() now = DateTime.now})
    : super(_initial(now()));

  final TasksApi _api;

  static HomeState _initial(DateTime now) =>
      HomeState(today: dateOnly(now), month: DateTime(now.year, now.month));

  Future<void> load() async {
    final user = await _api.me();
    final tabs = await _api.myTabs();
    final tab = tabs.first;
    emit(
      state.copyWith(
        user: user,
        tabs: tabs,
        activeTab: tab,
        tasks: await _api.tasksFor(tab),
      ),
    );
  }

  Future<void> selectTab(TaskTab tab) async {
    if (tab == state.activeTab) return;
    final tasks = await _api.tasksFor(tab);
    emit(
      state.copyWith(
        activeTab: tab,
        tasks: tasks,
        selectedDay: () => null,
        showCompleted: false,
      ),
    );
  }

  /// Tapping the selected day again clears the filter.
  void selectDay(DateTime day) {
    final same =
        state.selectedDay != null && isSameDay(state.selectedDay!, day);
    emit(state.copyWith(selectedDay: () => same ? null : day));
  }

  void clearDay() => emit(state.copyWith(selectedDay: () => null));

  void changeMonth(int delta) => emit(
    state.copyWith(
      month: DateTime(state.month.year, state.month.month + delta),
    ),
  );

  void toggleCompleted() =>
      emit(state.copyWith(showCompleted: !state.showCompleted));

  /// Throws [ProofRequired] when the task can't be ticked yet.
  Future<void> tick(Task task) async {
    final next = statusAfterTick(task);
    if (next == null) return;
    final updated = await _api.setStatus(task, next);
    emit(
      state.copyWith(
        tasks: [
          for (final t in state.tasks)
            t.id == updated.id && t.personal == updated.personal ? updated : t,
        ],
      ),
    );
  }
}
