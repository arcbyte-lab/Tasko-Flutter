import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'tasks_api.dart';

/// A division's live repeating tasks; null until loaded (arcbyte decision
/// 0012).
class RepeatingCubit extends Cubit<List<RepeatingSeries>?> {
  RepeatingCubit(this._api, this.tab) : super(null);

  final TasksApi _api;
  final TaskTab tab;

  Future<void> load() async => emit(await _api.repeatingFor(tab));
}
