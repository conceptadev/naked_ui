import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'semantics_test_utils.dart';

void main() {
  Widget _buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  Widget _buildNakedPopover() {
    return NakedPopover(
      popoverBuilder: (context, info) => Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Menu Item 1'),
            const SizedBox(height: 8),
            const Text('Menu Item 2'),
          ],
        ),
      ),
      child: const Text('Show Menu'),
    );
  }

  group('NakedPopover Semantics', () {
    testWidgets('basic popover trigger semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp(_buildNakedPopover()));

      // Verify trigger element has button-like semantics
      final summary = summarizeMergedFromRoot(
        tester,
        control: ControlType.button,
      );
      expect(summary.actions.contains('tap'), isTrue);
      expect(summary.flags.contains('isFocusable'), isTrue);

      handle.dispose();
    });

    testWidgets('popover opens and closes semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp(_buildNakedPopover()));

      // Initially closed
      expect(find.text('Show Menu'), findsOneWidget);
      expect(find.text('Menu Item 1'), findsNothing);

      // Tap to open
      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      // Verify popover is open
      expect(find.text('Menu Item 1'), findsOneWidget);
      expect(find.text('Menu Item 2'), findsOneWidget);

      // Tap outside to close
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Verify popover is closed
      expect(find.text('Menu Item 1'), findsNothing);

      handle.dispose();
    });

    testWidgets('keyboard focus semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp(_buildNakedPopover()));

      // Verify trigger is focusable (basic semantics test)
      final summary = summarizeMergedFromRoot(
        tester,
        control: ControlType.button,
      );
      expect(summary.flags.contains('isFocusable'), isTrue);

      handle.dispose();
    });

    testWidgets('escape key behavior semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp(_buildNakedPopover()));

      // Open popover first
      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      // Verify popover is open
      expect(find.text('Menu Item 1'), findsOneWidget);

      // Press Escape to close
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Verify popover closed
      expect(find.text('Menu Item 1'), findsNothing);

      handle.dispose();
    });

    testWidgets('focus management semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _buildTestApp(
          NakedPopover(
            popoverBuilder: (context, info) => Container(
              width: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Popover Content'),
            ),
            child: Focus(
              focusNode: focusNode,
              child: const Text('Focusable Trigger'),
            ),
          ),
        ),
      );

      // Request focus on the trigger
      focusNode.requestFocus();
      await tester.pump();

      // Verify focus is on the trigger
      expect(focusNode.hasFocus, isTrue);

      // Open popover
      await tester.tap(find.text('Focusable Trigger'));
      await tester.pumpAndSettle();

      // Verify popover is open
      expect(find.text('Popover Content'), findsOneWidget);

      focusNode.dispose();
      handle.dispose();
    });

    testWidgets('hover behavior semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await tester.pump();

      await tester.pumpWidget(_buildTestApp(_buildNakedPopover()));

      // Hover over trigger
      await mouse.moveTo(tester.getCenter(find.text('Show Menu')));
      await tester.pump();

      // Verify trigger responds to hover (basic test)
      expect(find.text('Show Menu'), findsOneWidget);

      await mouse.removePointer();
      handle.dispose();
    });

    testWidgets('disabled popover semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedPopover(
            openOnTap: false, // Disable tap interaction
            popoverBuilder: (context, info) => const Text('Disabled Popover'),
            child: const Text('Disabled Trigger'),
          ),
        ),
      );

      // Tap should not open the popover
      await tester.tap(find.text('Disabled Trigger'));
      await tester.pumpAndSettle();

      // Verify popover didn't open
      expect(find.text('Disabled Popover'), findsNothing);

      handle.dispose();
    });

    testWidgets('popover with custom positioning semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedPopover(
            popoverBuilder: (context, info) => Container(
              width: 150,
              height: 100,
              color: Colors.blue,
              child: const Center(child: Text('Positioned')),
            ),
            child: const Text('Position Test'),
          ),
        ),
      );

      // Open popover
      await tester.tap(find.text('Position Test'));
      await tester.pumpAndSettle();

      // Verify positioned popover is visible
      expect(find.text('Positioned'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('multiple popovers semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          Column(
            children: [
              NakedPopover(
                popoverBuilder: (context, info) => Container(
                  width: 150,
                  padding: const EdgeInsets.all(8),
                  color: Colors.red,
                  child: const Text('Popover 1'),
                ),
                child: const Text('Trigger 1'),
              ),
              const SizedBox(height: 50),
              NakedPopover(
                popoverBuilder: (context, info) => Container(
                  width: 150,
                  padding: const EdgeInsets.all(8),
                  color: Colors.blue,
                  child: const Text('Popover 2'),
                ),
                child: const Text('Trigger 2'),
              ),
            ],
          ),
        ),
      );

      // Open first popover
      await tester.tap(find.text('Trigger 1'));
      await tester.pumpAndSettle();

      expect(find.text('Popover 1'), findsOneWidget);
      expect(find.text('Popover 2'), findsNothing);

      // Tap outside to close first
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Popover 1'), findsNothing);

      // Open second popover
      await tester.tap(find.text('Trigger 2'));
      await tester.pumpAndSettle();

      expect(find.text('Popover 2'), findsOneWidget);

      handle.dispose();
    });
  });

  group('NakedPopover expanded/collapsed semantics', () {
    // Reads the disclosure state off the merged trigger node.
    Tristate expandedOf(WidgetTester tester, String triggerText) => tester
        .getSemantics(find.text(triggerText))
        .getSemanticsData()
        .flagsCollection
        .isExpanded;

    // AC: A closed component-owned trigger is a named, enabled, focusable button
    // with a tap action, has an expanded state, and reports isExpanded == false.
    testWidgets('closed trigger is a named, focusable, collapsed '
        'expandable button (NakedButton path)', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp(_buildNakedPopover()));

      expect(
        tester.getSemantics(find.text('Show Menu')),
        matchesSemantics(
          label: 'Show Menu',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      handle.dispose();
    });

    // AC: After opening isExpanded == true; after Escape or outside-tap
    // dismissal it reports isExpanded == false again.
    testWidgets('expanded state follows tap open, escape, and outside-tap '
        'dismissal', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp(_buildNakedPopover()));

      expect(expandedOf(tester, 'Show Menu'), Tristate.isFalse);

      // Open via tap.
      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();
      expect(expandedOf(tester, 'Show Menu'), Tristate.isTrue);

      // Close via Escape.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(expandedOf(tester, 'Show Menu'), Tristate.isFalse);

      // Re-open, then close via outside tap.
      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();
      expect(expandedOf(tester, 'Show Menu'), Tristate.isTrue);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(expandedOf(tester, 'Show Menu'), Tristate.isFalse);

      handle.dispose();
    });

    // AC: Controller-driven close reports isExpanded == false again.
    testWidgets('controller open/close updates trigger expanded state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = MenuController();

      await tester.pumpWidget(
        _buildTestApp(
          NakedPopover(
            controller: controller,
            popoverBuilder: (context, info) => const Text('Content'),
            child: const Text('Show Menu'),
          ),
        ),
      );

      expect(expandedOf(tester, 'Show Menu'), Tristate.isFalse);

      controller.open();
      await tester.pumpAndSettle();
      expect(expandedOf(tester, 'Show Menu'), Tristate.isTrue);

      controller.close();
      await tester.pumpAndSettle();
      expect(expandedOf(tester, 'Show Menu'), Tristate.isFalse);

      handle.dispose();
    });

    // AC: Both trigger construction paths have equivalent state semantics. This
    // exercises the child-owned Focus path (child is a Focus with its own node).
    testWidgets('child-owned Focus trigger exposes equivalent expanded state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _buildTestApp(
          NakedPopover(
            popoverBuilder: (context, info) => const Text('Content'),
            child: Focus(focusNode: focusNode, child: const Text('Trigger')),
          ),
        ),
      );

      // Closed: an expandable button reporting collapsed, equivalent to the
      // NakedButton path's state semantics.
      final closed = tester
          .getSemantics(find.text('Trigger'))
          .getSemanticsData();
      expect(closed.flagsCollection.isButton, isTrue);
      expect(closed.hasAction(SemanticsAction.tap), isTrue);
      expect(closed.flagsCollection.isExpanded, Tristate.isFalse);

      // Open and close via the trigger's own tap toggle.
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(expandedOf(tester, 'Trigger'), Tristate.isTrue);

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(expandedOf(tester, 'Trigger'), Tristate.isFalse);

      focusNode.dispose();
      handle.dispose();
    });

    // AC: openOnTap: false does not gain controller-mutating expand/collapse
    // actions; the trigger's activation policy stays caller-owned.
    testWidgets('openOnTap: false exposes no expand/collapse actions or state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedPopover(
            openOnTap: false,
            popoverBuilder: (context, info) => const Text('Content'),
            child: const Text('Trigger'),
          ),
        ),
      );

      final data = tester.getSemantics(find.text('Trigger')).getSemanticsData();
      expect(data.hasAction(SemanticsAction.expand), isFalse);
      expect(data.hasAction(SemanticsAction.collapse), isFalse);
      // No component-owned disclosure state either; the caller owns the trigger.
      expect(data.flagsCollection.isExpanded, Tristate.none);

      handle.dispose();
    });

    // AC: excludeSemantics: true continues to suppress the component's
    // semantics, including the new expanded state.
    testWidgets('excludeSemantics suppresses trigger button and expanded '
        'state', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedPopover(
            excludeSemantics: true,
            popoverBuilder: (context, info) => const Text('Content'),
            child: const Text('Show Menu'),
          ),
        ),
      );

      final data = tester
          .getSemantics(find.text('Show Menu'))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.flagsCollection.isExpanded, Tristate.none);

      handle.dispose();
    });
  });
}
