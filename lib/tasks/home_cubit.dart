import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'task_rules.dart';
import 'tasks_api.dart';
import 'view_options.dart';

class HomeState {
  const HomeState({
    required this.today,
    required this.month,
    required this.week,
    this.user,
    this.tabs = const [],
    this.activeTab,
    this.tasksByTab = const {},
    this.selectedDay,
    this.showCompleted = false,
    this.unread = 0,
    this.view = ViewOptions.defaults,
    this.query,
    this.membersByTab = const {},
    this.calendarExpanded = false,
    this.monthOpen = true,
  });

  /// Midnight of the current day; the cubit reads the clock once per load.
  final DateTime today;

  /// The first of the month the calendar shows.
  final DateTime month;

  /// The Monday of the week the collapsed calendar shows. Apart from
  /// [selectedDay]: swiping the strip moves the week, not the selection
  /// (arcbyte decision 0016).
  final DateTime week;
  final User? user;
  final List<TaskTab> tabs;
  final TaskTab? activeTab;

  /// Every tab's tasks, unfiltered, so the pages beside the current one are
  /// ready while a swipe drags them into view.
  final Map<TaskTab, List<Task>> tasksByTab;

  /// Every task in [activeTab], unfiltered.
  List<Task> get tasks => tasksByTab[activeTab] ?? const [];
  final DateTime? selectedDay;
  final bool showCompleted;

  /// Unread notifications, for the bell's dot.
  final int unread;

  /// Group, sort and filter from the view-options sheet.
  final ViewOptions view;

  /// Non-null while searching ("" before anything is typed).
  final String? query;

  /// Each tab's members, for assignee names. Empty for `private`.
  final Map<TaskTab, List<Member>> membersByTab;

  List<Member> get members => membersByTab[activeTab] ?? const [];

  /// The calendar fills the screen; tabs and list are hidden.
  final bool calendarExpanded;

  /// The whole month shows. When false and a day is selected, the calendar
  /// collapses to [week].
  final bool monthOpen;
  bool get showsWeek => selectedDay != null && !monthOpen;

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

  /// This state as the page for [tab] shows it: what [HomeCubit.selectTab]
  /// will produce once that page settles. The selected day stays (0016).
  HomeState pageFor(TaskTab tab) => tab == activeTab
      ? this
      : copyWith(
          activeTab: tab,
          showCompleted: false,
          view: view.withoutFilters(),
        );

  Map<int, int> get dueCountsThisMonth => dueCounts(tasks, month);

  /// Open tasks due each day of [month], for the full-screen titles.
  Map<int, List<Task>> get dueByDayThisMonth => dueByDay(tasks, month);

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
    DateTime? week,
    User? user,
    List<TaskTab>? tabs,
    TaskTab? activeTab,
    Map<TaskTab, List<Task>>? tasksByTab,
    DateTime? Function()? selectedDay,
    bool? showCompleted,
    int? unread,
    ViewOptions? view,
    String? Function()? query,
    Map<TaskTab, List<Member>>? membersByTab,
    bool? calendarExpanded,
    bool? monthOpen,
  }) => HomeState(
    today: today,
    month: month ?? this.month,
    week: week ?? this.week,
    user: user ?? this.user,
    tabs: tabs ?? this.tabs,
    activeTab: activeTab ?? this.activeTab,
    tasksByTab: tasksByTab ?? this.tasksByTab,
    selectedDay: selectedDay != null ? selectedDay() : this.selectedDay,
    showCompleted: showCompleted ?? this.showCompleted,
    unread: unread ?? this.unread,
    view: view ?? this.view,
    query: query != null ? query() : this.query,
    membersByTab: membersByTab ?? this.membersByTab,
    calendarExpanded: calendarExpanded ?? this.calendarExpanded,
    monthOpen: monthOpen ?? this.monthOpen,
  );
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._api, {DateTime Function() now = DateTime.now})
    : super(_initial(now()));

  final TasksApi _api;

  static HomeState _initial(DateTime now) => HomeState(
    today: dateOnly(now),
    month: DateTime(now.year, now.month),
    week: mondayOf(now),
  );

  /// Loads every tab at once, so a swipe never waits on the network.
  // ponytail: one request per tab on load; fine for a handful of tabs, page
  // them in lazily if users end up in dozens of projects.
  Future<void> load() async {
    final user = await _api.me();
    final tabs = await _api.myTabs();
    final tasks = await Future.wait(tabs.map(_api.tasksFor));
    final members = await Future.wait(tabs.map(_api.membersOf));
    emit(
      state.copyWith(
        user: user,
        tabs: tabs,
        activeTab: tabs.first,
        tasksByTab: Map.fromIterables(tabs, tasks),
        membersByTab: Map.fromIterables(tabs, members),
        unread: await _unread(),
      ),
    );
  }

  /// A project the viewer just created: last, where projects go, and shown.
  Future<void> addTab(TaskTab tab) async {
    final members = await _api.membersOf(tab);
    emit(
      state.copyWith(
        tabs: [...state.tabs, tab],
        tasksByTab: {...state.tasksByTab, tab: const []},
        membersByTab: {...state.membersByTab, tab: members},
      ),
    );
    await selectTab(tab);
  }

  /// Switches at once from what is loaded, then refreshes that tab.
  Future<void> selectTab(TaskTab tab) async {
    if (tab == state.activeTab) return;
    emit(state.pageFor(tab));
    await _refresh(tab);
  }

  /// Fetches the tab list again after a project was joined, left or
  /// re-roled. Known tabs keep their tasks; new ones are loaded; every tab's
  /// members are fetched again. If the active tab is gone, the first shows.
  Future<void> reloadTabs() async {
    final tabs = await _api.myTabs();
    final known = state.tasksByTab;
    final tasks = await Future.wait([
      for (final t in tabs)
        if (known[t] case final cached?)
          Future.value(cached)
        else
          _api.tasksFor(t),
    ]);
    final members = await Future.wait(tabs.map(_api.membersOf));
    final next = state.copyWith(
      tabs: tabs,
      tasksByTab: Map.fromIterables(tabs, tasks),
      membersByTab: Map.fromIterables(tabs, members),
    );
    final active = tabs.firstWhere(
      (t) => t == state.activeTab,
      orElse: () => tabs.first,
    );
    // Same tab: take the fresh object, which carries the viewer's new role.
    emit(
      active == state.activeTab
          ? next.copyWith(activeTab: active)
          : next.pageFor(active),
    );
  }

  /// Fetches the active tab's tasks and the unread count again, after a
  /// sheet or screen closes.
  Future<void> reload() async {
    await _refresh(state.activeTab!);
    emit(state.copyWith(unread: await _unread()));
  }

  Future<void> _refresh(TaskTab tab) async {
    final tasks = await _api.tasksFor(tab);
    emit(state.copyWith(tasksByTab: {...state.tasksByTab, tab: tasks}));
  }

  Future<int> _unread() async =>
      (await _api.notifications()).where((n) => n.unread).length;

  /// Selects [day], always: a second tap does not clear it (decision 0016).
  /// The calendar collapses to the day's week, out of full screen too.
  void selectDay(DateTime day) => emit(
    state.copyWith(
      selectedDay: () => dateOnly(day),
      week: mondayOf(day),
      month: DateTime(day.year, day.month),
      monthOpen: false,
      calendarExpanded: false,
    ),
  );

  void goToToday() => selectDay(state.today);

  /// Moves the collapsed calendar by weeks. The selected day and the list
  /// stay; only a tap selects (decision 0016).
  void changeWeek(int delta) {
    final w = state.week;
    final week = DateTime(w.year, w.month, w.day + 7 * delta);
    emit(state.copyWith(week: week, month: DateTime(week.year, week.month)));
  }

  void openMonth() => emit(state.copyWith(monthOpen: true));

  void toggleCalendar() =>
      emit(state.copyWith(calendarExpanded: !state.calendarExpanded));

  void clearDay() =>
      emit(state.copyWith(selectedDay: () => null, monthOpen: true));

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

  /// Throws [ProofRequired] when the task needs [proofUrl] to be ticked.
  Future<void> tick(Task task, {String? proofUrl}) async {
    final next = statusAfterTick(task, proofUrl: proofUrl);
    if (next == null) return;
    final updated = await _api.setStatus(task, next, proofUrl: proofUrl);
    // Finishing a repeating task made the next one on the server.
    if (task.repeat != null) return _refresh(state.activeTab!);
    emit(
      state.copyWith(
        tasksByTab: {
          ...state.tasksByTab,
          state.activeTab!: [
            for (final t in state.tasks)
              t.id == updated.id && t.personal == updated.personal
                  ? updated
                  : t,
          ],
        },
      ),
    );
  }
}
