import 'package:example/api/naked_link.0.dart' as link_example;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/keyboard_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NakedLink Integration Tests', () {
    testWidgets('Tab focuses the Link, Enter activates, and Space does not', (
      tester,
    ) async {
      await tester.pumpWidget(const link_example.MyApp());
      final primary = find.byKey(const ValueKey('link.primary'));

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.hasPrimaryFocusOn(primary), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text('Result: none'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('Result: documentation'), findsOneWidget);
      expect(tester.hasPrimaryFocusOn(primary), isTrue);
    });

    testWidgets('pointer hover, press, and tap expose exact state', (
      tester,
    ) async {
      await tester.pumpWidget(const link_example.MyApp());
      final primary = find.byKey(const ValueKey('link.primary'));
      final center = tester.getCenter(primary);

      final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await hover.addPointer(location: Offset.zero);
      addTearDown(hover.removePointer);
      await hover.moveTo(center);
      await tester.pump();
      expect(
        find.text('hovered:true focused:false pressed:false enabled:true'),
        findsOneWidget,
      );

      final press = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(
        find.text('hovered:true focused:false pressed:true enabled:true'),
        findsOneWidget,
      );

      await press.up();
      await tester.pump();
      expect(find.text('Result: documentation'), findsOneWidget);
      expect(
        find.text('hovered:true focused:false pressed:false enabled:true'),
        findsOneWidget,
      );
    });

    testWidgets('disabled Link is skipped and exposes no Link action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const link_example.MyApp());
        final primary = find.byKey(const ValueKey('link.primary'));
        final next = find.byKey(const ValueKey('link.next-focus'));

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(tester.hasPrimaryFocusOn(primary), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(tester.hasPrimaryFocusOn(next), isTrue);

        await tester.tap(find.byKey(const ValueKey('link.disabled')));
        await tester.pump();
        expect(find.text('Result: none'), findsOneWidget);

        final data = tester
            .getSemantics(find.text('Unavailable documentation'))
            .getSemanticsData();
        expect(data.flagsCollection.isLink, isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
      } finally {
        handle.dispose();
      }
    });
  });
}
