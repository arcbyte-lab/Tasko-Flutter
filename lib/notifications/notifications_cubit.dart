import 'package:flutter_bloc/flutter_bloc.dart';

import '../tasks/models.dart';
import '../tasks/tasks_api.dart';

/// The notification list; null until loaded.
class NotificationsCubit extends Cubit<List<AppNotification>?> {
  NotificationsCubit(this._api) : super(null);

  final TasksApi _api;

  Future<void> load() async => emit(await _api.notifications());

  Future<void> markRead(AppNotification n) async {
    if (!n.unread) return;
    await _api.markRead(n.id);
    await load();
  }

  Future<void> markAllRead() async {
    await _api.markAllRead();
    await load();
  }
}
