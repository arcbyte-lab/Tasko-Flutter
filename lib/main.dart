import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' show ClientException;

import 'auth/login_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/toast.dart';
import 'tasks/home_cubit.dart';
import 'tasks/http_tasks_api.dart';
import 'tasks/screens/home_panel.dart';
import 'tasks/tasks_api.dart';

final _navigator = GlobalKey<NavigatorState>();

void main() {
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('$error\n$stack');
    return toastError(_navigator.currentState?.overlay, error);
  };
  runApp(const TaskoApp());
}

/// Shows an error no screen handled, so nothing fails silently: the
/// server's message for a refused change (409, 422, …), "can't reach the
/// server" offline. A 401 shows nothing; the app is already back at login.
/// False when there is nowhere to show it yet.
bool toastError(OverlayState? overlay, Object error) {
  if (overlay == null) return false;
  final text = switch (error) {
    ApiException(status: 401) => null,
    ApiException(:final message) => message,
    ClientException() => "Can't reach the server",
    _ => 'Something went wrong',
  };
  if (text != null) showToastOn(overlay, text);
  return true;
}

/// Login, or home once a token is stored.
class TaskoApp extends StatefulWidget {
  const TaskoApp({super.key});

  @override
  State<TaskoApp> createState() => _TaskoAppState();
}

class _TaskoAppState extends State<TaskoApp> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'token';

  /// Null while the stored token is read.
  bool? _ready;
  HttpTasksApi? _api;

  @override
  void initState() {
    super.initState();
    _storage.read(key: _key).then((token) {
      setState(() {
        _ready = true;
        _api = token == null ? null : _apiFor(token);
      });
    });
  }

  HttpTasksApi _apiFor(String token) =>
      HttpTasksApi(token, onUnauthorized: _forget);

  Future<void> _login(String token) async {
    await _storage.write(key: _key, value: token);
    setState(() => _api = _apiFor(token));
  }

  Future<void> _forget() async {
    await _storage.delete(key: _key);
    _navigator.currentState?.popUntil((r) => r.isFirst); // open sheets too
    if (mounted) setState(() => _api = null);
  }

  Future<void> _logOut() async {
    final api = _api;
    await _forget();
    await api?.logout().catchError((_) {}); // the token is gone here anyway
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;
    return MaterialApp(
      title: 'Tasko',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      navigatorKey: _navigator,
      home: _ready == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : api == null
          ? LoginScreen(onLogin: _login)
          : RepositoryProvider<TasksApi>.value(
              key: ValueKey(api.token),
              value: api,
              child: BlocProvider(
                create: (_) => HomeCubit(api)..load(),
                child: HomePanel(onLogOut: _logOut),
              ),
            ),
    );
  }
}
