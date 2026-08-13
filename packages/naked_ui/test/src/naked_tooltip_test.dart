import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import '../test_helpers.dart';

void main() {
  group('NakedTooltip', () {
    group('Basic Functionality', () {
      testWidgets('renders child widget', (WidgetTester tester) async {
        await tester.pumpMaterialWidget(
          NakedTooltip(
            overlayBuilder: (context, animation) => const Text('Tooltip'),
            child: const Text('Hover me'),
          ),
        );

        expect(find.text('Hover me'), findsOneWidget);
      });

      testWidgets('does not show tooltip initially', (
        WidgetTester tester,
      ) async {
        await tester.pumpMaterialWidget(
          NakedTooltip(
            overlayBuilder: (context, animation) => const Text('Tooltip'),
            child: const Text('Hover me'),
          ),
        );

        expect(find.text('Tooltip'), findsNothing);
      });
    });

    group('Timer-based Show/Hide Behavior', () {
      testWidgets('shows tooltip after hoverDelay on mouse enter', (
        WidgetTester tester,
      ) async {
        const testKey = Key('test');
        await tester.pumpMaterialWidget(
          NakedTooltip(
            hoverDelay: const Duration(milliseconds: 100),
            dismissDelay: const Duration(seconds: 2),
            overlayBuilder: (context, animation) => const Text('Tooltip'),
            child: const SizedBox(key: testKey, width: 100, height: 100),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer();

        final center = tester.getCenter(find.byKey(testKey));
        await gesture.moveTo(center);
        await tester.pump();

        expect(find.text('Tooltip'), findsNothing);

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        expect(find.text('Tooltip'), findsOneWidget);

        await gesture.moveTo(const Offset(-1000, -1000));
        await tester.pumpAndSettle();
        await gesture.removePointer();
      });

      testWidgets('hides tooltip after dismissDelay on mouse exit', (
        WidgetTester tester,
      ) async {
        const testKey = Key('test');
        await tester.pumpMaterialWidget(
          NakedTooltip(
            hoverDelay: Duration.zero,
            dismissDelay: const Duration(milliseconds: 100),
            overlayBuilder: (context, animation) => const Text('Tooltip'),
            child: const SizedBox(key: testKey, width: 100, height: 100),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer();

        final center = tester.getCenter(find.byKey(testKey));
        await gesture.moveTo(center);
        await tester.pumpAndSettle();

        expect(find.text('Tooltip'), findsOneWidget);

        await gesture.moveTo(const Offset(-1000, -1000));
        await tester.pump();

        expect(find.text('Tooltip'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        expect(find.text('Tooltip'), findsNothing);
        await gesture.removePointer();
      });
    });

    group('Rapid Mouse Enter/Exit', () {
      testWidgets('cancels pending show on rapid mouse exit', (
        WidgetTester tester,
      ) async {
        const testKey = Key('test');

        await tester.pumpMaterialWidget(
          NakedTooltip(
            hoverDelay: const Duration(milliseconds: 100),
            overlayBuilder: (context, animation) => const Text('Tooltip'),
            child: const SizedBox(key: testKey, width: 100, height: 100),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer();

        final center = tester.getCenter(find.byKey(testKey));

        await gesture.moveTo(center);
        await tester.pump(const Duration(milliseconds: 50));

        await gesture.moveTo(const Offset(-1000, -1000));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('Tooltip'), findsNothing);
        await gesture.removePointer();
      });

      testWidgets('cancels pending hide on mouse re-enter', (
        WidgetTester tester,
      ) async {
        const testKey = Key('test');

        await tester.pumpMaterialWidget(
          NakedTooltip(
            hoverDelay: Duration.zero,
            dismissDelay: const Duration(milliseconds: 100),
            overlayBuilder: (context, animation) => const Text('Tooltip'),
            child: const SizedBox(key: testKey, width: 100, height: 100),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer();

        final center = tester.getCenter(find.byKey(testKey));

        await gesture.moveTo(center);
        await tester.pumpAndSettle();
        expect(find.text('Tooltip'), findsOneWidget);

        await gesture.moveTo(const Offset(-1000, -1000));
        await tester.pump(const Duration(milliseconds: 50));

        await gesture.moveTo(center);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('Tooltip'), findsOneWidget);

        await gesture.moveTo(const Offset(-1000, -1000));
        await tester.pumpAndSettle();
        await gesture.removePointer();
      });
    });

    group('Widget Disposal', () {
      testWidgets('cleans up when widget is removed', (
        WidgetTester tester,
      ) async {
        const testKey = Key('test');

        await tester.pumpMaterialWidget(
          NakedTooltip(
            hoverDelay: const Duration(milliseconds: 100),
            overlayBuilder: (context, animation) => const Text('Tooltip'),
            child: const SizedBox(key: testKey, width: 100, height: 100),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer();

        final center = tester.getCenter(find.byKey(testKey));
        await gesture.moveTo(center);
        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpMaterialWidget(const SizedBox.shrink());

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('Tooltip'), findsNothing);
        await gesture.removePointer();
      });
    });

    group('Semantics', () {
      testWidgets('includes semantics label when provided', (
        WidgetTester tester,
      ) async {
        final handle = tester.ensureSemantics();

        await tester.pumpMaterialWidget(
          NakedTooltip(
            semanticLabel: 'Help text',
            overlayBuilder: (context, animation) => const Text('Tooltip'),
            child: const Text('Hover me'),
          ),
        );

        final semantics = tester.getSemantics(find.text('Hover me'));
        expect(semantics.tooltip, 'Help text');
        handle.dispose();
      });

      testWidgets('excludeSemantics hides tooltip from accessibility', (
        WidgetTester tester,
      ) async {
        final handle = tester.ensureSemantics();

        await tester.pumpMaterialWidget(
          NakedTooltip(
            semanticLabel: 'Help text',
            excludeSemantics: true,
            overlayBuilder: (context, animation) => const Text('Tooltip'),
            child: const Text('Hover me'),
          ),
        );

        final semantics = tester.getSemantics(find.text('Hover me'));
        expect(semantics.tooltip, anyOf(isNull, isEmpty));
        handle.dispose();
      });
    });

    group('Positioning', () {
      testWidgets('uses provided positioning config', (
        WidgetTester tester,
      ) async {
        const testKey = Key('test');

        await tester.pumpMaterialWidget(
          Center(
            child: NakedTooltip(
              hoverDelay: Duration.zero,
              positioning: const OverlayPositionConfig(
                side: OverlaySide.bottom,
                alignment: OverlayAlignment.center,
                sideOffset: 8,
              ),
              overlayBuilder: (context, animation) => Container(
                key: const Key('tooltip'),
                color: Colors.black,
                child: const Text('Tooltip'),
              ),
              child: const SizedBox(key: testKey, width: 100, height: 50),
            ),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer();

        final center = tester.getCenter(find.byKey(testKey));
        await gesture.moveTo(center);
        await tester.pumpAndSettle();

        final childBox = tester.getRect(find.byKey(testKey));
        final tooltipBox = tester.getRect(find.byKey(const Key('tooltip')));

        expect(tooltipBox.top, greaterThanOrEqualTo(childBox.bottom));

        await gesture.moveTo(const Offset(-1000, -1000));
        await tester.pumpAndSettle();
        await gesture.removePointer();
      });
    });

    group('Animation', () {
      testWidgets('provides animation to overlayBuilder', (
        WidgetTester tester,
      ) async {
        const testKey = Key('test');
        Animation<double>? receivedAnimation;

        await tester.pumpMaterialWidget(
          NakedTooltip(
            hoverDelay: Duration.zero,
            overlayBuilder: (context, animation) {
              receivedAnimation = animation;
              return const Text('Tooltip');
            },
            child: const SizedBox(key: testKey, width: 100, height: 100),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer();

        final center = tester.getCenter(find.byKey(testKey));
        await gesture.moveTo(center);
        await tester.pumpAndSettle();

        expect(receivedAnimation, isNotNull);
        expect(receivedAnimation!.value, 1.0);

        await gesture.moveTo(const Offset(-1000, -1000));
        await tester.pumpAndSettle();
        await gesture.removePointer();
      });
    });

    group('Controlled visibility', () {
      testWidgets('hover only requests open when the owner rejects it', (
        WidgetTester tester,
      ) async {
        const triggerKey = Key('controlled-trigger');
        final requests = <bool>[];
        await tester.pumpMaterialWidget(
          NakedTooltip(
            open: false,
            onOpenChanged: requests.add,
            hoverDelay: Duration.zero,
            overlayBuilder: (context, animation) => const Text('Controlled'),
            child: const SizedBox(key: triggerKey, width: 100, height: 40),
          ),
        );

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(tester.getCenter(find.byKey(triggerKey)));
        await tester.pumpAndSettle();

        expect(requests, [true]);
        expect(find.text('Controlled'), findsNothing);
        await mouse.removePointer();
      });

      testWidgets('owner changes are the controlled source of truth', (
        WidgetTester tester,
      ) async {
        var open = false;
        late StateSetter setOwnerState;
        await tester.pumpMaterialWidget(
          StatefulBuilder(
            builder: (context, setState) {
              setOwnerState = setState;

              return NakedTooltip(
                open: open,
                onOpenChanged: (next) => setState(() => open = next),
                animationStyle: AnimationStyle.noAnimation,
                overlayBuilder: (context, animation) => const Text('Owned'),
                child: const SizedBox(width: 100, height: 40),
              );
            },
          ),
        );

        setOwnerState(() => open = true);
        await tester.pumpAndSettle();
        expect(find.text('Owned'), findsOneWidget);

        setOwnerState(() => open = false);
        await tester.pumpAndSettle();
        expect(find.text('Owned'), findsNothing);
      });

      testWidgets('a rejected close request leaves the tooltip open', (
        WidgetTester tester,
      ) async {
        const triggerKey = Key('reject-close-trigger');
        final requests = <bool>[];
        await tester.pumpMaterialWidget(
          NakedTooltip(
            open: true,
            onOpenChanged: requests.add,
            dismissDelay: Duration.zero,
            animationStyle: AnimationStyle.noAnimation,
            overlayBuilder: (context, animation) => const Text('Still open'),
            child: const SizedBox(key: triggerKey, width: 100, height: 40),
          ),
        );
        await tester.pumpAndSettle();

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(tester.getCenter(find.byKey(triggerKey)));
        await tester.pump();
        await mouse.moveTo(const Offset(-1000, -1000));
        await tester.pumpAndSettle();

        expect(requests, [false]);
        expect(find.text('Still open'), findsOneWidget);
        await mouse.removePointer();
      });

      testWidgets('switching to uncontrolled preserves the accepted state', (
        WidgetTester tester,
      ) async {
        bool? controlledOpen = true;
        late StateSetter setOwnerState;
        await tester.pumpMaterialWidget(
          StatefulBuilder(
            builder: (context, setState) {
              setOwnerState = setState;

              return NakedTooltip(
                open: controlledOpen,
                animationStyle: AnimationStyle.noAnimation,
                overlayBuilder: (context, animation) => const Text('Preserved'),
                child: const SizedBox(width: 100, height: 40),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Preserved'), findsOneWidget);

        setOwnerState(() => controlledOpen = null);
        await tester.pumpAndSettle();
        expect(find.text('Preserved'), findsOneWidget);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('Preserved'), findsNothing);
      });

      testWidgets('Escape dismisses even when tap dismissal is disabled', (
        WidgetTester tester,
      ) async {
        var open = true;
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await tester.pumpMaterialWidget(
          StatefulBuilder(
            builder: (context, setState) => NakedTooltip(
              open: open,
              onOpenChanged: (next) => setState(() => open = next),
              enableTapToDismiss: false,
              animationStyle: AnimationStyle.noAnimation,
              overlayBuilder: (context, animation) => const Text('Escape me'),
              child: Focus(
                focusNode: focusNode,
                child: const SizedBox(width: 100, height: 40),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        focusNode.requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(open, isFalse);
        expect(find.text('Escape me'), findsNothing);
      });
    });

    group('Hoverable content', () {
      testWidgets('moving into the overlay cancels pending dismissal', (
        WidgetTester tester,
      ) async {
        const triggerKey = Key('hoverable-trigger');
        const overlayKey = Key('hoverable-overlay');
        await tester.pumpMaterialWidget(
          NakedTooltip(
            hoverDelay: Duration.zero,
            dismissDelay: const Duration(milliseconds: 100),
            animationStyle: AnimationStyle.noAnimation,
            positioning: const OverlayPositionConfig(
              side: OverlaySide.bottom,
              alignment: OverlayAlignment.center,
            ),
            overlayBuilder: (context, animation) => const SizedBox(
              key: overlayKey,
              width: 120,
              height: 40,
              child: Text('Hoverable'),
            ),
            child: const SizedBox(key: triggerKey, width: 100, height: 40),
          ),
        );

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(tester.getCenter(find.byKey(triggerKey)));
        await tester.pumpAndSettle();
        await mouse.moveTo(tester.getCenter(find.byKey(overlayKey)));
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('Hoverable'), findsOneWidget);

        await mouse.moveTo(const Offset(-1000, -1000));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(find.text('Hoverable'), findsNothing);
        await mouse.removePointer();
      });

      testWidgets('disableHoverableContent closes over the overlay', (
        WidgetTester tester,
      ) async {
        const triggerKey = Key('nonhoverable-trigger');
        const overlayKey = Key('nonhoverable-overlay');
        await tester.pumpMaterialWidget(
          NakedTooltip(
            hoverDelay: Duration.zero,
            dismissDelay: const Duration(milliseconds: 50),
            disableHoverableContent: true,
            animationStyle: AnimationStyle.noAnimation,
            overlayBuilder: (context, animation) => const SizedBox(
              key: overlayKey,
              width: 120,
              height: 40,
              child: Text('Not hoverable'),
            ),
            child: const SizedBox(key: triggerKey, width: 100, height: 40),
          ),
        );

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(tester.getCenter(find.byKey(triggerKey)));
        await tester.pumpAndSettle();
        await mouse.moveTo(tester.getCenter(find.byKey(overlayKey)));
        await tester.pump(const Duration(milliseconds: 75));
        await tester.pumpAndSettle();

        expect(find.text('Not hoverable'), findsNothing);
        await mouse.removePointer();
      });
    });

    group('Resolved placement', () {
      testWidgets('overlay descendants receive collision-resolved placement', (
        WidgetTester tester,
      ) async {
        OverlayPlacement? placement;
        await tester.pumpMaterialWidget(
          Align(
            alignment: Alignment.bottomCenter,
            child: NakedTooltip(
              open: true,
              animationStyle: AnimationStyle.noAnimation,
              positioning: const OverlayPositionConfig(
                side: OverlaySide.bottom,
                alignment: OverlayAlignment.center,
                collisionPadding: EdgeInsets.all(8),
              ),
              overlayBuilder: (context, animation) => Builder(
                builder: (context) {
                  placement = OverlayPlacement.of(context);

                  return const SizedBox(width: 160, height: 100);
                },
              ),
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(placement, isNotNull);
        expect(placement!.side, OverlaySide.top);
        expect(placement!.wasFlipped, isTrue);
      });
    });
  });
}
