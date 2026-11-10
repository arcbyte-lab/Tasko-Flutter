import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'tasks_api.dart';

/// The Discussion list (hifi H13): tasks with comments, newest first,
/// searched by task name or code.
class DiscussionListCubit extends Cubit<DiscussionList?> {
  DiscussionListCubit(this._api) : super(null);

  final TasksApi _api;
  String _query = '';

  Future<void> load([String? query]) async {
    _query = query ?? _query;
    emit(await _api.discussions(query: _query));
  }
}

class ConversationState {
  const ConversationState({
    this.comments = const [],
    this.me,
    this.loading = true,
  });

  final List<Comment> comments;
  final User? me;
  final bool loading;
}

/// One conversation: a task's comments. Opening it marks it read.
class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit(this._api, this.task) : super(const ConversationState());

  final TasksApi _api;
  final Task task;

  Future<void> load() async {
    final me = await _api.me();
    final detail = await _api.detail(task);
    emit(ConversationState(comments: detail.comments, me: me, loading: false));
    await _api.markDiscussionRead(task);
  }

  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final c = await _api.addComment(task, body);
    emit(
      ConversationState(
        comments: [...state.comments, c],
        me: state.me,
        loading: false,
      ),
    );
  }
}
