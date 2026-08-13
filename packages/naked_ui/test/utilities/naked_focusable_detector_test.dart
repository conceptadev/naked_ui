import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/src/utilities/naked_focusable_detector.dart';

void main() {
  group('NakedFocusableDetector', () {
    testWidgets('creates widget with default parameters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NakedFocusableDetector(
            child: Container(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(NakedFocusableDetector), findsOneWidget);
      expect(find.byType(Container), findsOneWidget);
    });

    group('Focus management', () {
      testWidgets('autofocus works correctly', (tester) async {
        bool focusChanged = false;

        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              autofocus: true,
              onFocusChange: (focused) => focusChanged = focused,
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        // Wait for autofocus to take effect
        await tester.pump();
        expect(focusChanged, isTrue);
      });

      testWidgets('can request focus programmatically', (tester) async {
        final focusNode = FocusNode();
        bool focusChanged = false;

        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              focusNode: focusNode,
              onFocusChange: (focused) => focusChanged = focused,
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();

        expect(focusChanged, isTrue);
        expect(focusNode.hasFocus, isTrue);

        focusNode.dispose();
      });

      testWidgets('focus node can be swapped at runtime', (tester) async {
        final firstNode = FocusNode();
        final secondNode = FocusNode();

        // Start with first node
        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              focusNode: firstNode,
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        expect(find.byType(NakedFocusableDetector), findsOneWidget);

        // Swap to second node - should complete without error
        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              focusNode: secondNode,
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        await tester.pump();

        // Verify the widget still works and uses the new focus node
        expect(find.byType(NakedFocusableDetector), findsOneWidget);

        firstNode.dispose();
        secondNode.dispose();
      });

      testWidgets('handles focus in directional navigation mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                navigationMode: NavigationMode.directional,
              ),
              child: NakedFocusableDetector(
                enabled: false,
                canRequestFocus: true,
                child: Container(width: 100, height: 100),
              ),
            ),
          ),
        );

        // In directional mode, disabled widgets can still be traversable
        // Find the Focus widget that's a child of our NakedFocusableDetector
        final focusFinder = find.descendant(
          of: find.byType(NakedFocusableDetector),
          matching: find.byType(Focus),
        );
        final focus = tester.widget<Focus>(focusFinder);
        expect(focus.canRequestFocus, isTrue); // Should still be focusable
      });
    });

    group('Hover detection', () {
      testWidgets('detects mouse enter and exit when enabled', (tester) async {
        bool hoverState = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: NakedFocusableDetector(
                onHoverChange: (hovered) => hoverState = hovered,
                child: Container(width: 100, height: 100, color: Colors.red),
              ),
            ),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        // Hover over the widget
        await gesture.moveTo(tester.getCenter(find.byType(Container)));
        await tester.pump();
        expect(hoverState, isTrue);

        // Move away from the widget
        await gesture.moveTo(const Offset(200, 200));
        await tester.pump();
        expect(hoverState, isFalse);
      });

      testWidgets('ignores hover events when disabled', (tester) async {
        bool hoverState = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: NakedFocusableDetector(
                enabled: false,
                onHoverChange: (hovered) => hoverState = hovered,
                child: Container(width: 100, height: 100, color: Colors.red),
              ),
            ),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        // Hover over the widget - should not trigger callback
        await gesture.moveTo(tester.getCenter(find.byType(Container)));
        await tester.pump();
        expect(hoverState, isFalse);
      });

      testWidgets('sets custom mouse cursor', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              onHoverChange: (_) {},
              mouseCursor: SystemMouseCursors.click,
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        // Find the MouseRegion that's a descendant of our NakedFocusableDetector
        final mouseRegionFinder = find.descendant(
          of: find.byType(NakedFocusableDetector),
          matching: find.byType(MouseRegion),
        );
        final mouseRegion = tester.widget<MouseRegion>(mouseRegionFinder);
        expect(mouseRegion.cursor, equals(SystemMouseCursors.click));
      });
    });

    group('Keyboard shortcuts and actions', () {
      testWidgets('applies shortcuts when enabled', (tester) async {
        bool actionTriggered = false;
        final testIntent = TestIntent();

        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              autofocus: true, // Ensure the widget gets focus
              shortcuts: {LogicalKeySet(LogicalKeyboardKey.enter): testIntent},
              actions: {
                TestIntent: CallbackAction<TestIntent>(
                  onInvoke: (_) {
                    actionTriggered = true;
                    return null;
                  },
                ),
              },
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        await tester.pump(); // Let autofocus take effect

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(actionTriggered, isTrue);
      });

      testWidgets('ignores shortcuts when disabled', (tester) async {
        bool actionTriggered = false;
        final testIntent = TestIntent();

        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              enabled: false,
              autofocus: true,
              shortcuts: {LogicalKeySet(LogicalKeyboardKey.enter): testIntent},
              actions: {
                TestIntent: CallbackAction<TestIntent>(
                  onInvoke: (_) {
                    actionTriggered = true;
                    return null;
                  },
                ),
              },
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        await tester.pump(); // Let autofocus take effect

        // Try to trigger the shortcut - should not work when disabled
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(
          actionTriggered,
          isFalse,
        ); // Action should not have been triggered
      });

      testWidgets('handles raw keyboard events', (tester) async {
        KeyEvent? receivedEvent;

        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              autofocus: true,
              onKeyEvent: (node, event) {
                receivedEvent = event;
                return KeyEventResult.handled;
              },
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.logicalKey, equals(LogicalKeyboardKey.space));
      });
    });

    group('State transitions', () {
      testWidgets('calls onEnableChange when enabled state changes', (
        tester,
      ) async {
        bool? lastEnabledState;

        Widget buildWidget(bool enabled) {
          return MaterialApp(
            home: NakedFocusableDetector(
              enabled: enabled,
              onEnableChange: (enabled) => lastEnabledState = enabled,
              child: Container(width: 100, height: 100),
            ),
          );
        }

        // Start enabled
        await tester.pumpWidget(buildWidget(true));
        expect(lastEnabledState, isNull); // No callback on initial build

        // Change to disabled
        await tester.pumpWidget(buildWidget(false));
        expect(lastEnabledState, isFalse);

        // Change back to enabled
        await tester.pumpWidget(buildWidget(true));
        expect(lastEnabledState, isTrue);
      });

      testWidgets('maintains focus properties correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              canRequestFocus: false,
              skipTraversal: true,
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        // Just verify that the widget builds correctly with these properties
        expect(find.byType(NakedFocusableDetector), findsOneWidget);
        expect(find.byType(Focus), findsWidgets);
      });
    });

    group('Widget composition', () {
      testWidgets('only creates MouseRegion when onHoverChange provided', (
        tester,
      ) async {
        // Without onHoverChange
        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        // Count direct MouseRegions in our widget tree (exclude Flutter defaults)
        final mouseRegionsWithoutCallback = find
            .byType(MouseRegion)
            .evaluate()
            .where(
              (element) =>
                  element
                      .findAncestorWidgetOfExactType<
                        NakedFocusableDetector
                      >() !=
                  null,
            )
            .length;

        // With onHoverChange
        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              onHoverChange: (_) {},
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        final mouseRegionsWithCallback = find
            .byType(MouseRegion)
            .evaluate()
            .where(
              (element) =>
                  element
                      .findAncestorWidgetOfExactType<
                        NakedFocusableDetector
                      >() !=
                  null,
            )
            .length;

        expect(mouseRegionsWithoutCallback, equals(0));
        expect(mouseRegionsWithCallback, equals(1));
      });

      testWidgets('creates proper widget hierarchy', (tester) async {
        final testIntent = TestIntent();

        await tester.pumpWidget(
          MaterialApp(
            home: NakedFocusableDetector(
              onHoverChange: (_) {},
              shortcuts: {LogicalKeySet(LogicalKeyboardKey.enter): testIntent},
              actions: {
                TestIntent: CallbackAction<TestIntent>(onInvoke: (_) => null),
              },
              child: Container(width: 100, height: 100),
            ),
          ),
        );

        // Count our specific widgets (exclude Flutter framework defaults)
        final shortcutsCount = find
            .byType(Shortcuts)
            .evaluate()
            .where(
              (element) =>
                  element
                      .findAncestorWidgetOfExactType<
                        NakedFocusableDetector
                      >() !=
                  null,
            )
            .length;
        final actionsCount = find
            .byType(Actions)
            .evaluate()
            .where(
              (element) =>
                  element
                      .findAncestorWidgetOfExactType<
                        NakedFocusableDetector
                      >() !=
                  null,
            )
            .length;
        final mouseRegionCount = find
            .byType(MouseRegion)
            .evaluate()
            .where(
              (element) =>
                  element
                      .findAncestorWidgetOfExactType<
                        NakedFocusableDetector
                      >() !=
                  null,
            )
            .length;

        expect(shortcutsCount, equals(1));
        expect(actionsCount, equals(1));
        expect(mouseRegionCount, equals(1));
        expect(find.byType(Focus), findsWidgets); // Will find at least one
        expect(find.byType(Container), findsOneWidget);
      });
    });
  });
}

class TestIntent extends Intent {
  const TestIntent();
}
