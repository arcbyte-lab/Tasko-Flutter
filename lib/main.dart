import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'tasks/home_cubit.dart';
import 'tasks/screens/home_panel.dart';
import 'tasks/tasks_api.dart';

void main() {
  // ponytail: the fake API until the Laravel API lands; swap it here.
  final api = FakeTasksApi(today: DateTime.now());
  runApp(
    MaterialApp(
      title: 'Tasko',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: RepositoryProvider<TasksApi>.value(
        value: api,
        child: BlocProvider(
          create: (_) => HomeCubit(api)..load(),
          child: const HomePanel(),
        ),
      ),
    ),
  );
}
