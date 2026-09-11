import 'package:example/api/naked_toast.0.dart' as toast_example;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({Duration duration = const Duration(seconds: 5)}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: toast_example.ToastExample(duration: duration)),
    ),
  );
}

Finder _surface(String id) => find.byKey(ValueKey('toast.surface.$id'));

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
}

void main() {
  testWidgets('fixture stacks distinct toasts and replaces a repeated id', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await _tapKey(tester, 'toast.show.saved');
    await _tapKey(tester, 'toast.show.archived');
    await _tapKey(tester, 'toast.show.failed');
    await tester.pumpAndSettle();

    expect(_surface('saved'), findsOneWidget);
    expect(_surface('archived'), findsOneWidget);
    expect(_surface('failed'), findsOneWidget);
    // The newest toast sits nearest the bottom edge.
    expect(
      tester.getCenter(_surface('failed')).dy,
      greaterThan(tester.getCenter(_surface('archived')).dy),
    );
    expect(
      tester.getCenter(_surface('archived')).dy,
      greaterThan(tester.getCenter(_surface('saved')).dy),
    );

    await _tapKey(tester, 'toast.show.saved');
    await tester.pumpAndSettle();

    expect(_surface('saved'), findsOneWidget);
    expect(find.text('Last result: replaced; undo count: 0'), findsOneWidget);
  });

  testWidgets('action dismisses its toast and clear dismisses the rest', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await _tapKey(tester, 'toast.show.archived');
    await _tapKey(tester, 'toast.show.failed');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('toast.action.archived')));
    await tester.pumpAndSettle();

    expect(_surface('archived'), findsNothing);
    expect(_surface('failed'), findsOneWidget);
    expect(find.text('Last result: action; undo count: 1'), findsOneWidget);

    await _tapKey(tester, 'toast.clear');
    await tester.pumpAndSettle();

    expect(_surface('failed'), findsNothing);
    expect(
      find.text('Last result: programmatic; undo count: 1'),
      findsOneWidget,
    );
  });

  testWidgets('timed toasts close on timeout while the alert persists', (
    tester,
  ) async {
    await tester.pumpWidget(_app(duration: const Duration(seconds: 2)));

    await _tapKey(tester, 'toast.show.saved');
    await _tapKey(tester, 'toast.show.failed');
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(_surface('saved'), findsNothing);
    expect(_surface('failed'), findsOneWidget);
    expect(find.text('Last result: timeout; undo count: 0'), findsOneWidget);
  });
}
