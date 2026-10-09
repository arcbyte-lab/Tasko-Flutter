import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:tasko/main.dart';
import 'package:tasko/tasks/http_tasks_api.dart';

void main() {
  testWidgets('unhandled errors show as a toast, over an open sheet', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Scaffold()),
    );
    showModalBottomSheet<void>(
      context: navigator.currentContext!,
      builder: (_) => const SizedBox(height: 300),
    );
    await tester.pumpAndSettle();
    final overlay = navigator.currentState!.overlay;

    Future<void> expectToast(Object error, String? text) async {
      expect(toastError(overlay, error), isTrue);
      await tester.pump();
      if (text != null) expect(find.text(text), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    }

    await expectToast(
      const ApiException(422, 'Cannot move a task from waiting to in_progress'),
      'Cannot move a task from waiting to in_progress',
    );
    await expectToast(ClientException('no route'), "Can't reach the server");
    await expectToast(StateError('x'), 'Something went wrong');
    await expectToast(const ApiException(401, 'Unauthorized'), null);
    expect(find.text('Unauthorized'), findsNothing);

    expect(toastError(null, StateError('x')), isFalse);
  });
}
