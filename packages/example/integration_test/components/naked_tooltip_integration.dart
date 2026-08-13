import 'package:example/api/naked_tooltip.0.dart' as tooltip_example;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naked_ui/naked_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NakedTooltip Integration Tests', () {
    testWidgets('tooltip shows on hover and hides on exit', (tester) async {
      await tester.pumpWidget(const tooltip_example.MyApp());
      await tester.pump(const Duration(milliseconds: 100));

      final tooltipFinder = find.byType(NakedTooltip);
      expect(tooltipFinder, findsOneWidget);

      final triggerFinder = tooltipFinder;

      expect(find.text('This is a tooltip'), findsNothing);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(triggerFinder));
      await tester.pumpAndSettle();

      expect(find.text('This is a tooltip'), findsOneWidget);

      await gesture.moveTo(const Offset(0, 0));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('This is a tooltip'), findsNothing);
    }, skip: true);

    testWidgets('tooltip respects hover delay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedTooltip(
                hoverDelay: const Duration(milliseconds: 500),
                dismissDelay: Duration.zero,
                overlayBuilder: (context, animation) => Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Tooltip',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Hover me',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final triggerFinder = find.text('Hover me');
      expect(triggerFinder, findsOneWidget);

      expect(find.text('Tooltip'), findsNothing);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(triggerFinder));

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Tooltip'), findsNothing);

      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Tooltip'), findsOneWidget);
    });

    testWidgets('tooltip shows on hover with zero durations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedTooltip(
                hoverDelay: Duration.zero,
                dismissDelay: Duration.zero,
                overlayBuilder: (context, animation) => Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Tooltip',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Hover me',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final triggerFinder = find.text('Hover me');
      expect(triggerFinder, findsOneWidget);

      expect(find.text('Tooltip'), findsNothing);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(triggerFinder));
      await tester.pumpAndSettle();

      expect(find.text('Tooltip'), findsOneWidget);

      await gesture.moveTo(const Offset(0, 0));
      await tester.pumpAndSettle();
      expect(find.text('Tooltip'), findsNothing);
    });

    testWidgets('tooltip positioning works correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedTooltip(
                positioning: const OverlayPositionConfig(
                  side: OverlaySide.bottom,
                  alignment: OverlayAlignment.center,
                ),
                hoverDelay: Duration.zero,
                dismissDelay: Duration.zero,
                overlayBuilder: (context, animation) => Container(
                  width: 100,
                  height: 50,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Positioned Tooltip',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
                child: Container(
                  width: 80,
                  height: 40,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Trigger',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final triggerFinder = find.byType(NakedTooltip);
      expect(triggerFinder, findsOneWidget);

      expect(find.text('Positioned Tooltip'), findsNothing);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(triggerFinder));
      await tester.pumpAndSettle();

      expect(find.text('Positioned Tooltip'), findsOneWidget);

      final tooltipRect = tester.getRect(find.text('Positioned Tooltip'));

      expect(tooltipRect.size.height, greaterThan(0));
      expect(tooltipRect.size.width, greaterThan(0));
      expect(tooltipRect.top, greaterThanOrEqualTo(0));
      expect(tooltipRect.left, greaterThanOrEqualTo(0));
    });
  });
}
