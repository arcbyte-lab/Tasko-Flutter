import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'task_rules.dart';
import 'tasks_api.dart';
import 'view_options.dart';

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
    this.unread = 0,
    this.view = ViewOptions.defaults,
    this.query,
    this.members = const [],
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

  /// Unread notifications, for the bell's dot.
  final int unread;

  /// Group, sort and filter from the view-options sheet.
  final ViewOptions view;

  /// Non-null while searching ("" before anything is typed).
  final String? query;

  /// The active tab's members, for assignee names. Empty in `private`.
  final List<Member> members;

  bool get loading => user == null;
  bool get searching => query != null;

  bool _shown(Task t) =>
      (selectedDay == null ||
          (t.dueDate != null && isSameDay(t.dueDate!, selectedDay!))) &&
      (query == null ||
          t.name.toLowerCase().contains(query!.trim().toLowerCase())) &&
      view.matches(t);

  /// Not done, filtered and sorted.
  List<Task> get listed =>
      view.sort(tasks.where((t) => t.status != TaskStatus.done && _shown(t)));

  List<Task> get completed =>
      view.sort(tasks.where((t) => t.status == TaskStatus.done && _shown(t)));

  /// [listed] under headers. A selected day or a search shows one flat
  /// block, as the mockups do.
  List<Section> get sections => selectedDay != null || searching
      ? [(label: null, alert: false, tasks: listed)]
      : view.sections(
          listed,
          now: today,
          names: {
            for (final m in members)
              m.user.id: m.user.id == user?.id ? 'me' : m.user.name,
          },
        );

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
    int? unread,
    ViewOptions? view,
    String? Function()? query,
    List<Member>? members,
  }) => HomeState(
    today: today,
    month: month ?? this.month,
    user: user ?? this.user,
    tabs: tabs ?? this.tabs,
    activeTab: activeTab ?? this.activeTab,
    tasks: tasks ?? this.tasks,
    selectedDay: selectedDay != null ? selectedDay() : this.selectedDay,
    showCompleted: showCompleted ?? this.showCompleted,
    unread: unread ?? this.unread,
    view: view ?? this.view,
    query: query != null ? query() : this.query,
    members: members ?? this.members,
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
        unread: await _unread(),
        members: await _api.membersOf(tab),
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
        members: await _api.membersOf(tab),
        selectedDay: () => null,
        showCompleted: false,
        view: state.view.withoutFilters(),
      ),
    );
  }

  /// Fetches the active tab's tasks and the unread count again, after a
  /// sheet or screen closes.
  Future<void> reload() async => emit(
    state.copyWith(
      tasks: await _api.tasksFor(state.activeTab!),
      unread: await _unread(),
    ),
  );

  Future<int> _unread() async =>
      (await _api.notifications()).where((n) => n.unread).length;

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

  void setView(ViewOptions v) => emit(state.copyWith(view: v));

  void startSearch() => emit(state.copyWith(query: () => ''));
  void search(String q) => emit(state.copyWith(query: () => q));
  void stopSearch() => emit(state.copyWith(query: () => null));

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
