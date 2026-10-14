import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';
import 'tasks_api.dart';

/// A project's members; null until loaded. Every change reloads the list,
/// so it shows what the server kept (arcbyte decision 0010).
class MembersCubit extends Cubit<List<Member>?> {
  MembersCubit(this._api, this.tab) : super(null);

  final TasksApi _api;
  final TaskTab tab;

  Future<void> load() async => emit(await _api.membersOf(tab));

  Future<List<User>> search(String q) => _api.searchUsers(q);

  Future<void> add(User user) async {
    await _api.addMember(tab, user.id);
    await load();
  }

  Future<void> setRole(Member m, String role) async {
    await _api.setMemberRole(tab, m.user.id, role);
    await load();
  }

  Future<void> remove(Member m) async {
    await _api.removeMember(tab, m.user.id);
    await load();
  }

  /// The viewer leaves. No reload: the server no longer lets them see the
  /// list, so the screen closes instead.
  Future<void> leave(Member me) => _api.removeMember(tab, me.user.id);
}
