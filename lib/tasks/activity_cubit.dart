import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'tasks_api.dart';

/// One activity log, newest first (arcbyte decision 0014). [items] is null
/// until loaded; [next] is the cursor for "load more", null at the end.
typedef ActivityState = ({List<ActivityEntry>? items, int? next});

class ActivityCubit extends Cubit<ActivityState> {
  ActivityCubit(this._api, this.scope) : super((items: null, next: null));

  final TasksApi _api;
  final ActivityScope scope;

  // A page can land after the screen has gone (closed while Task Detail was
  // open, say): then it is dropped.
  Future<void> load() async {
    final page = await _api.activity(scope);
    if (isClosed) return;
    emit((items: page.items, next: page.next));
  }

  /// The next page. The cursor is cleared while it loads, so a second tap
  /// can't fetch the same page twice.
  Future<void> more() async {
    final (:items, :next) = state;
    if (next == null) return;
    emit((items: items, next: null));
    final page = await _api.activity(scope, before: next);
    if (isClosed) return;
    emit((items: [...?items, ...page.items], next: page.next));
  }
}
