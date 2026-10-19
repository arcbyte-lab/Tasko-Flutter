import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'tasks_api.dart';

/// Every occurrence of one repeating task, newest first; null until loaded
/// (arcbyte decision 0012).
class SeriesCubit extends Cubit<List<Occurrence>?> {
  SeriesCubit(this._api, this.seriesId) : super(null);

  final TasksApi _api;
  final int seriesId;

  Future<void> load() async => emit(await _api.seriesHistory(seriesId));

  /// The open occurrence, which carries the rule. Null once it stopped.
  Task? get open =>
      state?.map((o) => o.task).where((t) => t.repeat != null).firstOrNull;

  /// Null stops it repeating; the open task stays as a one-off.
  Future<void> setRepeat(Repeat? r) async {
    await _api.updateTask(open!.copyWith(repeat: () => r));
    await load();
  }

  /// Deletes the open task and its rule. The server refuses (409) once
  /// someone has started it.
  Future<void> delete() => _api.deleteSeries(seriesId);
}
