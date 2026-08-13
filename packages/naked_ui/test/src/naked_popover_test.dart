import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import '../test_helpers.dart';
import 'helpers/builder_state_scope.dart';

Matcher _closeTo(double v, [double eps = 0.5]) =>
    moreOrLessEquals(v, epsilon: eps);

void main() {
  group('NakedPopover', () {
    testWidgets('renders child and is closed by default', (tester) async {
      await tester.pumpMaterialWidget(
        NakedPopover(
          popoverBuilder: (context, info) => const Text('Popover Content'),
          child: const Text('Trigger'),
        ),
      );

      expect(find.text('Trigger'), findsOneWidget);
      expect(find.text('Popover Content'), findsNothing);
    });

    testWidgets('opens on tap and closes on outside tap', (tester) async {
      await tester.pumpMaterialWidget(
        Center(
          child: NakedPopover(
            popoverBuilder: (context, info) => const Text('Popover Content'),
            child: const Text('Trigger'),
          ),
        ),
      );

      expect(find.text('Popover Content'), findsNothing);

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle(); // robust against future animations
      expect(find.text('Popover Content'), findsOneWidget);

      // Tap outside to close
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Popover Content'), findsNothing);
    });

    testWidgets('toggles via trigger (tap again closes)', (tester) async {
      await tester.pumpMaterialWidget(
        Center(
          child: NakedPopover(
            popoverBuilder: (context, info) => const Text('Popover Content'),
            child: const Text('Trigger'),
          ),
        ),
      );

      await tester.tap(find.text('Trigger')); // open
      await tester.pumpAndSettle();
      expect(find.text('Popover Content'), findsOneWidget);

      await tester.tap(find.text('Trigger')); // close
      await tester.pumpAndSettle();
      expect(find.text('Popover Content'), findsNothing);
    });

    testWidgets(
      'closes on Escape key (overlay had focus) and returns focus to trigger',
      (tester) async {
        final triggerFocusNode = FocusNode(debugLabel: 'trigger');

        await tester.pumpMaterialWidget(
          Center(
            child: NakedPopover(
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: Focus(
                // give the trigger a node we can assert on
                focusNode: triggerFocusNode,
                child: const Text('Trigger'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();
        expect(find.text('Popover Content'), findsOneWidget);

        // Press ESC to dismiss
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Popover Content'), findsNothing);

        // Focus should return to trigger (RawMenuAnchor.childFocusNode path)
        expect(triggerFocusNode.hasFocus, isTrue);
      },
    );

    testWidgets('a caller-provided Focus child is the only trigger tab stop', (
      tester,
    ) async {
      final before = FocusNode(debugLabel: 'before popover');
      final trigger = FocusNode(debugLabel: 'popover trigger');
      final after = FocusNode(debugLabel: 'after popover');
      addTearDown(before.dispose);
      addTearDown(trigger.dispose);
      addTearDown(after.dispose);

      await tester.pumpMaterialWidget(
        Column(
          children: [
            Focus(focusNode: before, child: const SizedBox(height: 20)),
            NakedPopover(
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: Focus(
                focusNode: trigger,
                child: const SizedBox(
                  width: 100,
                  height: 40,
                  child: Text('Trigger'),
                ),
              ),
            ),
            Focus(focusNode: after, child: const SizedBox(height: 20)),
          ],
        ),
      );

      before.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(trigger.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);
    });

    testWidgets('a Focus child without a node does not add a tab stop', (
      tester,
    ) async {
      final before = FocusNode(debugLabel: 'before popover');
      final after = FocusNode(debugLabel: 'after popover');
      addTearDown(before.dispose);
      addTearDown(after.dispose);

      await tester.pumpMaterialWidget(
        Column(
          children: [
            Focus(focusNode: before, child: const SizedBox(height: 20)),
            NakedPopover(
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: const Focus(
                child: SizedBox(width: 100, height: 40, child: Text('Trigger')),
              ),
            ),
            Focus(focusNode: after, child: const SizedBox(height: 20)),
          ],
        ),
      );

      before.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);
    });

    testWidgets('caller-owned trigger reports keyboard pressed state', (
      tester,
    ) async {
      final trigger = FocusNode(debugLabel: 'popover trigger');
      addTearDown(trigger.dispose);
      Set<WidgetState> states = {};

      await tester.pumpMaterialWidget(
        NakedPopover(
          popoverBuilder: (context, info) => const Text('Popover Content'),
          builder: (context, state, child) {
            states = state.states;
            return child!;
          },
          child: Focus(
            focusNode: trigger,
            child: const SizedBox(
              width: 100,
              height: 40,
              child: Text('Trigger'),
            ),
          ),
        ),
      );

      trigger.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(states, contains(WidgetState.pressed));
      expect(find.text('Popover Content'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(states, isNot(contains(WidgetState.pressed)));
    });

    testWidgets('opens via Space key on trigger (internal focus)', (
      tester,
    ) async {
      await tester.pumpMaterialWidget(
        Center(
          child: NakedPopover(
            popoverBuilder: (context, info) => const Text('Popover Content'),
            child: const Text('Trigger'),
          ),
        ),
      );

      // Focus the trigger via TAB (FocusTraversal) then activate with Space
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.text('Popover Content'), findsOneWidget);
    });

    testWidgets('opens via Enter key on trigger (internal focus)', (
      tester,
    ) async {
      await tester.pumpMaterialWidget(
        Center(
          child: NakedPopover(
            popoverBuilder: (context, info) => const Text('Popover Content'),
            child: const Text('Trigger'),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Popover Content'), findsOneWidget);
    });

    testWidgets('positions popover based on anchors', (tester) async {
      const triggerKey = Key('trigger');
      const popoverKey = Key('popover');

      await tester.pumpMaterialWidget(
        Center(
          child: NakedPopover(
            positioning: const OverlayPositionConfig(
              alignment: OverlayAlignment.center,
            ),
            popoverBuilder: (context, info) => const SizedBox(
              key: popoverKey,
              width: 100,
              height: 60,
              child: Text('Popover Content'),
            ),
            child: const SizedBox(
              key: triggerKey,
              width: 80,
              height: 40,
              child: Text('Trigger'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(triggerKey));
      await tester.pumpAndSettle();

      final triggerCenter = tester.getCenter(find.byKey(triggerKey));
      final popoverCenter = tester.getCenter(find.byKey(popoverKey));
      expect(popoverCenter.dx, _closeTo(triggerCenter.dx)); // horizontal align

      // Popover top aligns to trigger bottom (follower top to target bottom)
      final triggerBottom = tester.getBottomLeft(find.byKey(triggerKey)).dy;
      final popoverTop = tester.getTopLeft(find.byKey(popoverKey)).dy;
      expect(popoverTop, _closeTo(triggerBottom));
    });

    testWidgets('can position against a separate keyed anchor', (tester) async {
      final anchorKey = GlobalKey();
      const triggerKey = Key('separate-trigger');
      const popoverKey = Key('separate-popover');
      Rect? builderAnchorRect;

      await tester.pumpMaterialWidget(
        Stack(
          children: [
            Positioned(
              left: 80,
              top: 60,
              child: SizedBox(key: anchorKey, width: 120, height: 40),
            ),
            Positioned(
              left: 300,
              top: 160,
              child: NakedPopover(
                anchorKey: anchorKey,
                positioning: const OverlayPositionConfig(
                  avoidCollisions: false,
                ),
                popoverBuilder: (context, info) {
                  builderAnchorRect = info.anchorRect;
                  return const SizedBox(
                    key: popoverKey,
                    width: 80,
                    height: 30,
                    child: Text('Separate content'),
                  );
                },
                child: const SizedBox(
                  key: triggerKey,
                  width: 40,
                  height: 30,
                  child: Text('Separate trigger'),
                ),
              ),
            ),
          ],
        ),
      );

      await tester.tap(find.byKey(triggerKey));
      await tester.pumpAndSettle();

      final anchorRect = tester.getRect(find.byKey(anchorKey));
      final popoverRect = tester.getRect(find.byKey(popoverKey));
      expect(builderAnchorRect, anchorRect);
      expect(popoverRect.topLeft, anchorRect.bottomLeft);
    });

    testWidgets('outside tap: true swallows, false propagates', (tester) async {
      var backgroundTaps = 0;

      Future<void> mount({required bool consumeOutsideTaps}) async {
        backgroundTaps = 0;
        await tester.pumpMaterialWidget(
          Stack(
            children: [
              // Background tap target to detect propagation
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => backgroundTaps++,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
              Center(
                child: NakedPopover(
                  popoverBuilder: (context, info) => const SizedBox(
                    width: 100,
                    height: 60,
                    child: Text('Popover Content'),
                  ),
                  child: const Text('Trigger'),
                  consumeOutsideTaps: consumeOutsideTaps,
                ),
              ),
            ],
          ),
        );
      }

      // consumeOutsideTaps = true: outside tap closes and does not propagate
      await mount(consumeOutsideTaps: true);
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Popover Content'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Popover Content'), findsNothing);
      expect(backgroundTaps, 0, reason: 'outside tap is swallowed');

      // consumeOutsideTaps = false: outside tap closes and propagates
      await mount(consumeOutsideTaps: false);
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Popover Content'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Popover Content'), findsNothing);
      expect(
        backgroundTaps,
        greaterThan(0),
        reason: 'outside tap propagates when not consumed',
      );
    });

    testWidgets('ESC closes even when no outside space is tappable', (
      tester,
    ) async {
      // Regression test: if the overlay covers the whole screen with hit testing,
      // DismissIntent should still close via ESC.
      await tester.pumpMaterialWidget(
        SizedBox.expand(
          child: Center(
            child: NakedPopover(
              popoverBuilder: (context, info) => const SizedBox(
                width: 120,
                height: 80,
                child: Text('Popover Content'),
              ),
              child: const Text('Trigger'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Popover Content'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Popover Content'), findsNothing);
    });

    testStateScopeBuilder<NakedPopoverState>(
      'builder\'s context contains NakedStateScope',
      (builder) => NakedPopover(
        popoverBuilder: (context, info) =>
            const SizedBox(child: Text('Popover Content')),
        builder: builder,
        child: const Text('Trigger'),
      ),
    );

    testWidgets('builder exposes pressed and open interaction states', (
      tester,
    ) async {
      NakedPopoverState? state;

      await tester.pumpMaterialWidget(
        Center(
          child: NakedPopover(
            popoverBuilder: (context, info) => const Text('Popover Content'),
            builder: (context, value, child) {
              state = value;
              return const SizedBox(
                key: Key('trigger'),
                width: 100,
                height: 40,
              );
            },
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('trigger'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(state!.isPressed, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(state!.isPressed, isFalse);
      expect(state!.isOpen, isTrue);
    });

    group('openOnTap behavior', () {
      testWidgets('does not open on tap when openOnTap is false', (
        tester,
      ) async {
        await tester.pumpMaterialWidget(
          Center(
            child: NakedPopover(
              openOnTap: false,
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: const Text('Trigger'),
            ),
          ),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        expect(
          find.text('Popover Content'),
          findsNothing,
          reason: 'popover should not open when openOnTap is false',
        );
      });

      testWidgets('can still open via controller when openOnTap is false', (
        tester,
      ) async {
        final controller = MenuController();

        await tester.pumpMaterialWidget(
          Center(
            child: NakedPopover(
              openOnTap: false,
              controller: controller,
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: const Text('Trigger'),
            ),
          ),
        );

        expect(find.text('Popover Content'), findsNothing);

        controller.open();
        await tester.pumpAndSettle();

        expect(find.text('Popover Content'), findsOneWidget);
      });
    });

    group('lifecycle callbacks', () {
      testWidgets('calls onOpen when popover opens', (tester) async {
        bool onOpenCalled = false;

        await tester.pumpMaterialWidget(
          Center(
            child: NakedPopover(
              onOpen: () => onOpenCalled = true,
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: const Text('Trigger'),
            ),
          ),
        );

        expect(onOpenCalled, isFalse);

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        expect(onOpenCalled, isTrue);
      });

      testWidgets('calls onClose when popover closes', (tester) async {
        bool onCloseCalled = false;

        await tester.pumpMaterialWidget(
          Center(
            child: NakedPopover(
              onClose: () => onCloseCalled = true,
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: const Text('Trigger'),
            ),
          ),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        expect(onCloseCalled, isFalse);

        // Close by tapping outside
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        expect(onCloseCalled, isTrue);
      });
    });

    group('custom open/close request handlers', () {
      testWidgets('onOpenRequested can prevent opening', (tester) async {
        bool customShowCalled = false;

        await tester.pumpMaterialWidget(
          Center(
            child: NakedPopover(
              onOpenRequested: (info, show) {
                customShowCalled = true;
                // Intentionally not calling show() to prevent opening
              },
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: const Text('Trigger'),
            ),
          ),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        expect(customShowCalled, isTrue);
        expect(
          find.text('Popover Content'),
          findsNothing,
          reason: 'popover should not open when show() is not called',
        );
      });

      testWidgets('onCloseRequested can delay closing', (tester) async {
        bool customHideCalled = false;
        VoidCallback? storedHide;

        await tester.pumpMaterialWidget(
          Center(
            child: NakedPopover(
              onCloseRequested: (hide) {
                customHideCalled = true;
                storedHide = hide;
                // Intentionally not calling hide() immediately
              },
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: const Text('Trigger'),
            ),
          ),
        );

        // Open popover
        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();
        expect(find.text('Popover Content'), findsOneWidget);

        // Tap outside to trigger close request
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        expect(customHideCalled, isTrue);
        expect(
          find.text('Popover Content'),
          findsOneWidget,
          reason: 'popover should still be open until hide() is called',
        );

        // Now call hide
        storedHide?.call();
        await tester.pumpAndSettle();

        expect(find.text('Popover Content'), findsNothing);
      });
    });

    group('controller', () {
      testWidgets('uses a replacement external controller', (tester) async {
        final firstController = MenuController();
        final secondController = MenuController();
        late StateSetter rebuild;
        MenuController controller = firstController;

        await tester.pumpMaterialWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedPopover(
                controller: controller,
                popoverBuilder: (context, info) =>
                    const Text('Popover Content'),
                child: const Text('Trigger'),
              );
            },
          ),
        );

        rebuild(() => controller = secondController);
        await tester.pump();

        secondController.open();
        await tester.pumpAndSettle();
        expect(find.text('Popover Content'), findsOneWidget);
        expect(secondController.isOpen, isTrue);
      });

      testWidgets('can open and close via external controller', (tester) async {
        final controller = MenuController();

        await tester.pumpMaterialWidget(
          Center(
            child: NakedPopover(
              controller: controller,
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: const Text('Trigger'),
            ),
          ),
        );

        expect(find.text('Popover Content'), findsNothing);

        controller.open();
        await tester.pumpAndSettle();
        expect(find.text('Popover Content'), findsOneWidget);

        controller.close();
        await tester.pumpAndSettle();
        expect(find.text('Popover Content'), findsNothing);
      });

      testWidgets('controller.isOpen reflects current state', (tester) async {
        final controller = MenuController();

        await tester.pumpMaterialWidget(
          Center(
            child: NakedPopover(
              controller: controller,
              popoverBuilder: (context, info) => const Text('Popover Content'),
              child: const Text('Trigger'),
            ),
          ),
        );

        expect(controller.isOpen, isFalse);

        controller.open();
        await tester.pumpAndSettle();
        expect(controller.isOpen, isTrue);

        controller.close();
        await tester.pumpAndSettle();
        expect(controller.isOpen, isFalse);
      });
    });
  });
}
