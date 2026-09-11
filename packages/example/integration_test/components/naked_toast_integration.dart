import 'package:example/api/naked_toast.0.dart' as toast_example;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/test_helpers.dart';

Widget _app({Duration duration = const Duration(seconds: 5)}) {
  return MaterialApp(
    home: Scaffold(
      // Triggers sit at the top start so the bottom-end stack never covers
      // them.
      body: SizedBox.expand(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: toast_example.ToastExample(duration: duration),
          ),
        ),
      ),
    ),
  );
}

Finder _surface(String id) => find.byKey(ValueKey('toast.surface.$id'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NakedToast Integration Tests', () {
    testWidgets('action dismisses its toast with the action reason', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.tap(find.byKey(const ValueKey('toast.show.archived')));
      await tester.pumpAndSettle();
      expect(_surface('archived'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('toast.action.archived')));
      await tester.pumpAndSettle();

      expect(_surface('archived'), findsNothing);
      expect(find.text('Last result: action; undo count: 1'), findsOneWidget);
    });

    testWidgets('Escape dismisses the toast that contains focus', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.tap(find.byKey(const ValueKey('toast.show.failed')));
      await tester.pumpAndSettle();

      // Showing a toast never moves focus; move it into the toast explicitly.
      Focus.of(tester.element(find.text('Retry'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_surface('failed'), findsNothing);
      expect(find.text('Last result: close; undo count: 0'), findsOneWidget);
    });

    testWidgets('hover pauses the countdown until the pointer leaves', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(duration: const Duration(milliseconds: 1500)),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await tester.tap(find.byKey(const ValueKey('toast.show.saved')));
      await tester.pumpAndSettle();
      await gesture.moveTo(tester.getCenter(_surface('saved')));
      await tester.pump();

      // Twice the duration: the hovered toast must still be visible.
      await tester.pump(const Duration(seconds: 3));
      expect(_surface('saved'), findsOneWidget);

      await gesture.moveTo(Offset.zero);
      await tester.pumpUntil(
        () => _surface('saved').evaluate().isEmpty,
        timeout: const Duration(seconds: 5),
      );
      expect(find.text('Last result: timeout; undo count: 0'), findsOneWidget);
    });
  });
}
