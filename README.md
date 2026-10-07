# Tasko (Flutter)

Team and personal tasks. The thinking lives in arcbyte (`ideas/tasko/`); this
repo is the code.

Right now it is the home screen (calendar heatmap, workspace and project
tabs, the task list and its checkbox), the create sheet with its pickers,
Task Detail (edits, sub-tasks, discussion, review, extension requests), and
the notifications screen,
running on `FakeTasksApi` seed data.
The Laravel API comes later: swap the API in `lib/main.dart`.

```
flutter run
flutter analyze && flutter test
```
