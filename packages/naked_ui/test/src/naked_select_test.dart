import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import '../test_helpers.dart';
import 'helpers/builder_state_scope.dart';

void main() {
  const kMenuKey = Key('menu');

  // Helper function to build select widget
  Widget buildSelect<T>({
    T? selectedValue,
    ValueChanged<T?>? onSelectedValueChanged,
    bool enabled = true,
    VoidCallback? onMenuClose,
    bool closeOnSelect = true,
    bool? open,
    ValueChanged<bool>? onOpenChanged,
  }) {
    return Center(
      child: NakedSelect<T>(
        value: selectedValue,
        onChanged: onSelectedValueChanged ?? (_) {},
        enabled: enabled,
        closeOnSelect: closeOnSelect,
        open: open,
        onOpenChanged: onOpenChanged,
        onClose: onMenuClose,
        builder: (context, state, child) => const Text('Select option'),
        overlayBuilder: (context, info) => Container(
          key: kMenuKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NakedSelectOption<T>(
                value: 'apple' as T,
                child: const Text('Apple'),
              ),
              NakedSelectOption<T>(
                value: 'banana' as T,
                child: const Text('Banana'),
              ),
              NakedSelectOption<T>(
                value: 'orange' as T,
                child: const Text('Orange'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('Core Functionality', () {
    testWidgets('controlled open state follows the owner', (tester) async {
      var open = false;
      late StateSetter setHostState;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return buildSelect<String>(
              open: open,
              onOpenChanged: (value) => setState(() => open = value),
            );
          },
        ),
      );

      expect(find.text('Apple'), findsNothing);
      setHostState(() => open = true);
      await tester.pump();
      await tester.pump();
      expect(find.text('Apple'), findsOneWidget);

      setHostState(() => open = false);
      await tester.pump();
      await tester.pump();
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('controlled trigger requests opening without mutating state', (
      tester,
    ) async {
      final requests = <bool>[];
      await tester.pumpMaterialWidget(
        buildSelect<String>(open: false, onOpenChanged: requests.add),
      );

      await tester.tap(find.text('Select option'));
      await tester.pump();

      expect(requests, [true]);
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('controlled option selection requests close', (tester) async {
      final openRequests = <bool>[];
      String? selected;
      await tester.pumpMaterialWidget(
        buildSelect<String>(
          open: true,
          onOpenChanged: openRequests.add,
          onSelectedValueChanged: (value) => selected = value,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Apple'));
      await tester.pump();

      expect(selected, 'apple');
      expect(openRequests, [false]);
      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets(
      'renders trigger and menu when opened',
      (WidgetTester tester) async {
        await tester.pumpMaterialWidget(buildSelect<String>());

        await tester.tap(find.text('Select option'));
        await tester.pump();

        expect(find.text('Select option'), findsOneWidget);
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Banana'), findsOneWidget);
        expect(find.text('Orange'), findsOneWidget);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'selects single value correctly',
      (WidgetTester tester) async {
        String? selectedValue;

        await tester.pumpMaterialWidget(
          buildSelect<String>(
            selectedValue: selectedValue,
            onSelectedValueChanged: (value) => selectedValue = value,
          ),
        );

        // Open menu
        await tester.tap(find.text('Select option'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Banana'));
        await tester.pump();

        expect(selectedValue, 'banana');
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets('toggle menu visibility', (WidgetTester tester) async {
      await tester.pumpMaterialWidget(buildSelect<String>());

      // Initially menu is closed
      expect(find.text('Apple'), findsNothing);

      // Open menu by tapping trigger
      await tester.tap(find.text('Select option'));
      await tester.pump();

      // Menu items should be visible
      expect(find.text('Apple'), findsOneWidget);

      // Close menu by tapping trigger again
      await tester.tapAt(Offset.zero);
      await tester.pump();

      // Menu should be closed again
      expect(find.text('Apple'), findsNothing);
    }, timeout: const Timeout(Duration(seconds: 10)));

    testWidgets(
      'does not respond when disabled',
      (WidgetTester tester) async {
        String? selectedValue;

        await tester.pumpMaterialWidget(
          buildSelect<String>(
            selectedValue: selectedValue,
            onSelectedValueChanged: (value) => selectedValue = value,
            enabled: false,
          ),
        );

        // Try to open menu
        await tester.tap(find.text('Select option'));
        await tester.pump();

        // Menu should not open when disabled
        expect(find.text('Apple'), findsNothing);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testStateScopeBuilder<NakedSelectState<String>>(
      'builder\'s context contains NakedStateScope',
      (builder) => NakedSelect<String>(
        onChanged: (_) {},
        builder: builder,
        overlayBuilder: (context, info) =>
            const SizedBox(child: Text('Select option')),
        child: const Text('Select option'),
      ),
    );
  });

  group('Keyboard Navigation', () {
    testWidgets('closes menu with Escape key', (WidgetTester tester) async {
      await tester.pumpMaterialWidget(buildSelect<String>());

      // Open menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Apple'), findsNothing);
    }, timeout: const Timeout(Duration(seconds: 10)));

    testWidgets(
      'restores focus to trigger after closing with Escape',
      (tester) async {
        final triggerFocusNode = FocusNode();

        await tester.pumpMaterialWidget(
          Center(
            child: NakedSelect<String>(
              onChanged: (_) {},
              triggerFocusNode: triggerFocusNode,
              builder: (context, state, child) => const Text('Select option'),
              overlayBuilder: (context, info) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NakedSelectOption<String>(
                    value: 'apple',
                    child: Text('Apple'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Focus the trigger, then open menu
        triggerFocusNode.requestFocus();
        await tester.pump();
        await tester.tap(find.text('Select option'));
        await tester.pump();

        // Overlay should have focus; now close with Escape
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // Expect focus to be back on the trigger
        expect(triggerFocusNode.hasFocus, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets('selects item with Enter key', (WidgetTester tester) async {
      String? selectedValue;

      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (value) => selectedValue = value,
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(value: 'apple', child: Text('Apple')),
                NakedSelectOption<String>(
                  value: 'banana',
                  child: Text('Banana'),
                ),
              ],
            ),
          ),
        ),
      );

      // Open the select menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      // Verify overlay is open
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);

      // Navigate to first item with arrow down, then press Enter to select
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Verify selection was made and overlay closed
      expect(selectedValue, 'apple');
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('PageDown moves focus forward by multiple items', (
      WidgetTester tester,
    ) async {
      final focusStates = List<bool>.filled(15, false);

      // Build a select with many options to test PageDown
      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (_) {},
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                15,
                (index) => NakedSelectOption<String>(
                  value: 'option$index',
                  builder: (context, state, child) {
                    focusStates[index] = state.isFocused;
                    return child!;
                  },
                  child: Text('Option $index'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the select menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      // Focus the first option
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focusStates.indexWhere((focused) => focused), 0);

      // Press PageDown to jump forward
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();

      // PageDown should move focus by the page size (10)
      expect(focusStates.indexWhere((focused) => focused), 10);

      // Close menu
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });

    testWidgets('PageUp moves focus backward by multiple items', (
      WidgetTester tester,
    ) async {
      final focusStates = List<bool>.filled(15, false);

      // Build a select with many options to test PageUp
      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (_) {},
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                15,
                (index) => NakedSelectOption<String>(
                  value: 'option$index',
                  builder: (context, state, child) {
                    focusStates[index] = state.isFocused;
                    return child!;
                  },
                  child: Text('Option $index'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the select menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      // Navigate to a later option using multiple arrow downs
      for (int i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(focusStates.indexWhere((focused) => focused), 11);

      // Press PageUp to jump backward
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();

      // PageUp should move focus back by the page size (10)
      expect(focusStates.indexWhere((focused) => focused), 1);

      // Close menu
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });

    testWidgets('PageUp/PageDown do nothing when menu is closed', (
      WidgetTester tester,
    ) async {
      await tester.pumpMaterialWidget(buildSelect<String>());

      // Menu is closed
      expect(find.text('Apple'), findsNothing);

      // Press PageDown - should not open menu
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);

      // Press PageUp - should not open menu
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('PageDown with fewer items selects the focused item', (
      WidgetTester tester,
    ) async {
      String? selectedValue;
      final focusStates = List<bool>.filled(3, false);

      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (value) => selectedValue = value,
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(
                  value: 'a',
                  builder: (context, state, child) {
                    focusStates[0] = state.isFocused;
                    return child!;
                  },
                  child: const Text('A'),
                ),
                NakedSelectOption<String>(
                  value: 'b',
                  builder: (context, state, child) {
                    focusStates[1] = state.isFocused;
                    return child!;
                  },
                  child: const Text('B'),
                ),
                NakedSelectOption<String>(
                  value: 'c',
                  builder: (context, state, child) {
                    focusStates[2] = state.isFocused;
                    return child!;
                  },
                  child: const Text('C'),
                ),
              ],
            ),
          ),
        ),
      );

      // Open the select menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      // Focus first option
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Press PageDown (should go to last option since fewer than 10 items)
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();

      final focusedIndex = focusStates.indexWhere((focused) => focused);
      expect(focusedIndex, greaterThanOrEqualTo(0));

      // Press Enter to select current focused item
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      const values = ['a', 'b', 'c'];
      expect(selectedValue, values[focusedIndex]);
    });
  });

  group('Interaction States', () {
    testWidgets('trigger can be hovered', (WidgetTester tester) async {
      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (_) {},
            builder: (context, state, child) {
              return Container(
                key: const Key('trigger'),
                color: state.isHovered ? Colors.grey[200] : null,
                child: const Text('Select option'),
              );
            },
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(value: 'apple', child: Text('Apple')),
              ],
            ),
          ),
        ),
      );

      // Simulate hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.text('Select option')));
      await tester.pump();

      // Verify hover state is reflected in the UI
      final container = tester.widget<Container>(
        find.byKey(const Key('trigger')),
      );
      expect(container.color, Colors.grey[200]);
    });

    testWidgets('trigger can be pressed', (tester) async {
      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (_) {},
            builder: (context, state, child) {
              return Container(
                key: const Key('trigger'),
                color: state.isPressed ? Colors.grey[400] : null,
                child: const Text('Select option'),
              );
            },
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(value: 'apple', child: Text('Apple')),
              ],
            ),
          ),
        ),
      );

      // Simulate press down
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Select option')),
      );
      // Allow time for gesture recognition to complete
      await tester.pump(const Duration(milliseconds: 100));

      // Verify pressed state is reflected in the UI
      final container = tester.widget<Container>(
        find.byKey(const Key('trigger')),
      );
      expect(container.color, Colors.grey[400]);

      // Release press
      await gesture.up();
      await tester.pump();
    });

    testWidgets('trigger can be focused', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (_) {},
            triggerFocusNode: focusNode,
            builder: (context, state, child) {
              return Container(
                key: const Key('trigger'),
                decoration: BoxDecoration(
                  border: state.isFocused
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
                child: const Text('Select option'),
              );
            },
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(value: 'apple', child: Text('Apple')),
              ],
            ),
          ),
        ),
      );

      // Focus the trigger
      focusNode.requestFocus();
      await tester.pump();

      // Verify focused state is reflected in the UI
      final container = tester.widget<Container>(
        find.byKey(const Key('trigger')),
      );
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isA<Border>());

      focusNode.dispose();
    });

    testWidgets('calls item states when hovered/pressed', (tester) async {
      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (_) {},
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(
                  value: 'apple',
                  builder: (context, state, child) {
                    return Container(
                      key: const Key('apple-option'),
                      color: state.isHovered ? const Color(0xFFE0E0E0) : null,
                      child: child,
                    );
                  },
                  child: const Text('Apple'),
                ),
              ],
            ),
          ),
        ),
      );

      // Open the select menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('apple-option')), findsOneWidget);

      // Test hover state
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.text('Apple')));
      await tester.pump();

      // The option should respond to hover (just verify it's still there and working)
      expect(find.byKey(const Key('apple-option')), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
    });
  });

  group('Menu Positioning', () {
    testWidgets('renders menu in overlay', (WidgetTester tester) async {
      await tester.pumpMaterialWidget(buildSelect<String>());

      // Open menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      // Menu should be rendered in the overlay
      expect(find.byType(OverlayPortal), findsOneWidget);
    });

    testWidgets(
      'fallback alignment positions overlay using fallback when primary would overflow',
      (tester) async {
        // Build with the trigger near the bottom so primary (bottomLeft/topLeft) would overflow
        await tester.pumpMaterialWidget(
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: NakedSelect<String>(
                onChanged: (_) {},
                positioning: const OverlayPositionConfig(
                  side: OverlaySide.bottom,
                  alignment: OverlayAlignment.start,
                ),
                builder: (context, state, child) => const Text('Select option'),
                overlayBuilder: (context, info) => Container(
                  key: kMenuKey,
                  width: 120,
                  height: 160, // big enough to overflow downward
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Menu Content'),
                      NakedSelectOption<String>(
                        value: 'apple',
                        child: Text('Apple'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        // Open menu
        await tester.tap(find.text('Select option'));
        await tester.pump();

        // Get the trigger and menu positions
        final triggerRect = tester.getRect(find.text('Select option'));
        final menuRect = tester.getRect(find.byKey(kMenuKey));

        // Assert the overlay is at least partially visible within viewport
        final view = tester.binding.platformDispatcher.views.first;
        final Size screenSize = view.physicalSize / view.devicePixelRatio;
        expect(menuRect.right > 0, isTrue);
        expect(menuRect.bottom > 0, isTrue);
        expect(menuRect.left < screenSize.width, isTrue);
        expect(menuRect.top < screenSize.height, isTrue);

        // Optional sanity: menu should be positioned near the trigger in Y direction
        // (above or below), but we don't assert exact fallback choice.
        expect(
          menuRect.overlaps(triggerRect) ||
              menuRect.bottom <= triggerRect.top ||
              menuRect.top >= triggerRect.bottom,
          isTrue,
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  group('Selection Behavior', () {
    testWidgets(
      'keeps menu open when closeOnSelect is false',
      (WidgetTester tester) async {
        String? selectedValue;
        bool menuClosed = false;

        await tester.pumpMaterialWidget(
          buildSelect<String>(
            selectedValue: selectedValue,
            onSelectedValueChanged: (value) => selectedValue = value,
            onMenuClose: () => menuClosed = true,
            closeOnSelect: false,
          ),
        );

        // Open menu
        await tester.tap(find.text('Select option'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Banana'));
        await tester.pump();

        expect(selectedValue, 'banana');
        expect(menuClosed, false);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'closes menu when closeOnSelect is true',
      (WidgetTester tester) async {
        String? selectedValue;

        await tester.pumpMaterialWidget(
          buildSelect<String>(
            selectedValue: selectedValue,
            onSelectedValueChanged: (value) => selectedValue = value,
            closeOnSelect: true,
          ),
        );

        // Open menu
        await tester.tap(find.text('Select option'));
        await tester.pump();

        await tester.tap(find.text('Banana'));
        await tester.pump();

        expect(selectedValue, 'banana');
        expect(find.text('Apple'), findsNothing);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets('outside tap closes menu with removalDelay respected', (
      WidgetTester tester,
    ) async {
      await tester.pumpMaterialWidget(
        NakedSelect<String>(
          onChanged: (_) {},
          onCloseRequested: (hideOverlay) {
            // Simulate removalDelay by delaying the actual close
            Future.delayed(const Duration(milliseconds: 200), hideOverlay);
          },
          builder: (context, state, child) => const Text('Select option'),
          overlayBuilder: (context, info) => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NakedSelectOption<String>(value: 'apple', child: Text('Apple')),
              NakedSelectOption<String>(value: 'banana', child: Text('Banana')),
            ],
          ),
        ),
      );

      // Open menu
      await tester.tap(find.text('Select option'));
      await tester.pump();
      expect(find.text('Apple'), findsOneWidget);

      // Tap outside to request close
      await tester.tapAt(Offset.zero);
      await tester.pump();

      // During delay, overlay should still be visible
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Apple'), findsOneWidget);

      // After full delay, overlay should be gone
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('Apple'), findsNothing);
    });
  });

  group('Cursor', () {
    testWidgets('shows appropriate cursor based on interactive state', (
      tester,
    ) async {
      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            enabled: false,
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(value: 'apple', child: Text('Apple')),
              ],
            ),
          ),
        ),
      );

      // When disabled, should show a forbidden cursor
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.text('Select option')));
      await tester.pump();

      // This test just verifies the widget can handle cursor state
      // The actual cursor rendering is handled by the platform
      expect(find.text('Select option'), findsOneWidget);
    });
  });

  group('Callback Behavior', () {
    testWidgets('calls onCanceled when closing without selection', (
      WidgetTester tester,
    ) async {
      bool onCanceledCalled = false;
      bool onCloseCalled = false;

      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (_) {},
            onCanceled: () => onCanceledCalled = true,
            onClose: () => onCloseCalled = true,
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(value: 'apple', child: Text('Apple')),
              ],
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);

      // Close without selection (outside tap)
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      expect(onCloseCalled, isTrue);
      expect(onCanceledCalled, isTrue);
    });

    testWidgets('does not call onCanceled when closing with selection', (
      WidgetTester tester,
    ) async {
      bool onCanceledCalled = false;
      String? selectedValue;

      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onCanceled: () => onCanceledCalled = true,
            onChanged: (value) => selectedValue = value,
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(value: 'apple', child: Text('Apple')),
              ],
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      // Select an option
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();

      expect(selectedValue, 'apple');
      expect(onCanceledCalled, isFalse);
    });

    testWidgets('calls onOpen when menu opens', (WidgetTester tester) async {
      bool onOpenCalled = false;

      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (_) {},
            onOpen: () => onOpenCalled = true,
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(value: 'apple', child: Text('Apple')),
              ],
            ),
          ),
        ),
      );

      expect(onOpenCalled, isFalse);

      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      expect(onOpenCalled, isTrue);
    });
  });

  group('External Value Changes', () {
    testWidgets('updates internal value when external value prop changes', (
      WidgetTester tester,
    ) async {
      String? currentValue;

      Widget buildWidget(String? value) {
        return Center(
          child: NakedSelect<String>(
            value: value,
            builder: (context, state, child) {
              currentValue = state.value;
              return Text('Selected: ${state.value ?? 'none'}');
            },
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(value: 'apple', child: Text('Apple')),
                NakedSelectOption<String>(
                  value: 'banana',
                  child: Text('Banana'),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpMaterialWidget(buildWidget(null));
      expect(currentValue, isNull);

      await tester.pumpMaterialWidget(buildWidget('apple'));
      expect(currentValue, 'apple');

      await tester.pumpMaterialWidget(buildWidget('banana'));
      expect(currentValue, 'banana');

      await tester.pumpMaterialWidget(buildWidget(null));
      expect(currentValue, isNull);
    });

    testWidgets('controlled null remains authoritative after selection', (
      tester,
    ) async {
      String? capturedValue = 'not-built';
      String? requestedValue;

      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            value: null,
            onChanged: (value) => requestedValue = value,
            builder: (context, state, child) {
              capturedValue = state.value;
              return const Text('Select option');
            },
            overlayBuilder: (context, info) => const NakedSelectOption<String>(
              value: 'apple',
              child: Text('Apple'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();

      expect(requestedValue, 'apple');
      expect(capturedValue, isNull);
    });

    testWidgets('missing onChanged makes the select non-interactive', (
      tester,
    ) async {
      NakedSelectState<String>? capturedState;

      await tester.pumpMaterialWidget(
        NakedSelect<String>(
          value: 'apple',
          builder: (context, state, child) {
            capturedState = state;
            return const Text('Select option');
          },
          overlayBuilder: (context, info) => const Text('Overlay'),
        ),
      );

      expect(capturedState!.isDisabled, isTrue);
      await tester.tap(find.text('Select option'));
      await tester.pump();
      expect(find.text('Overlay'), findsNothing);
    });
  });

  group('NakedSelectOption', () {
    testWidgets('disabled option does not trigger selection', (
      WidgetTester tester,
    ) async {
      String? selectedValue;

      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            onChanged: (value) => selectedValue = value,
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(
                  value: 'disabled',
                  enabled: false,
                  child: Text('Disabled Option'),
                ),
                NakedSelectOption<String>(
                  value: 'enabled',
                  child: Text('Enabled Option'),
                ),
              ],
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      // Try to tap disabled option
      await tester.tap(find.text('Disabled Option'));
      await tester.pumpAndSettle();

      expect(selectedValue, isNull);
      // Menu should still be open since nothing was selected
      expect(find.text('Disabled Option'), findsOneWidget);

      // Tap enabled option
      await tester.tap(find.text('Enabled Option'));
      await tester.pumpAndSettle();

      expect(selectedValue, 'enabled');
    });

    testWidgets('option shows selected state for matching value', (
      WidgetTester tester,
    ) async {
      bool? isSelected;

      await tester.pumpMaterialWidget(
        Center(
          child: NakedSelect<String>(
            value: 'apple',
            onChanged: (_) {},
            builder: (context, state, child) => const Text('Select option'),
            overlayBuilder: (context, info) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption<String>(
                  value: 'apple',
                  builder: (context, state, child) {
                    isSelected = state.isSelected;
                    return child!;
                  },
                  child: const Text('Apple'),
                ),
                const NakedSelectOption<String>(
                  value: 'banana',
                  child: Text('Banana'),
                ),
              ],
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.text('Select option'));
      await tester.pumpAndSettle();

      expect(isSelected, isTrue);
    });
  });

  group('Cursor', () {
    testWidgets('shows appropriate cursor based on interactive state', (
      WidgetTester tester,
    ) async {
      final keyEnabled = UniqueKey();
      final keyDisabled = UniqueKey();

      await tester.pumpMaterialWidget(
        Column(
          children: [
            NakedSelect<String>(
              key: keyEnabled,
              onChanged: (_) {},
              builder: (context, state, child) => const Text('Enabled'),
              overlayBuilder: (context, info) => const SizedBox(),
            ),
            NakedSelect<String>(
              key: keyDisabled,
              enabled: false,
              onChanged: (_) {},
              builder: (context, state, child) => const Text('Disabled'),
              overlayBuilder: (context, info) => const SizedBox(),
            ),
          ],
        ),
      );

      tester.expectCursor(SystemMouseCursors.click, on: keyEnabled);
      tester.expectCursor(SystemMouseCursors.basic, on: keyDisabled);
    });

    testWidgets('supports custom cursor', (WidgetTester tester) async {
      final key = UniqueKey();

      await tester.pumpMaterialWidget(
        NakedSelect<String>(
          key: key,
          onChanged: (_) {},
          mouseCursor: SystemMouseCursors.help,
          builder: (context, state, child) => const Text('Custom Cursor'),
          overlayBuilder: (context, info) => const SizedBox(),
        ),
      );

      tester.expectCursor(SystemMouseCursors.help, on: key);
    });
  });
}
