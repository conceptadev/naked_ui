import 'dart:ui' show SemanticsRole, Tristate;

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

  Widget _buildNakedSelect({String? selectedValue, bool enabled = true}) {
    return NakedSelect<String>(
      value: selectedValue,
      onChanged: enabled ? (value) {} : null,
      enabled: enabled,
      builder: (context, state, child) => const Text('Select Option'),
      overlayBuilder: (context, info) => Container(
        width: 200,
        padding: const EdgeInsets.all(8),
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NakedSelectOption(value: 'option1', child: Text('Option 1')),
            NakedSelectOption(value: 'option2', child: Text('Option 2')),
            NakedSelectOption(value: 'option3', child: Text('Option 3')),
          ],
        ),
      ),
    );
  }

  group('NakedSelect Semantics', () {
    testWidgets('select trigger button semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp(_buildNakedSelect()));

      // Verify trigger has button semantics
      final summary = summarizeMergedFromRoot(
        tester,
        control: ControlType.button,
      );
      expect(summary.label, 'Select Option');
      expect(summary.flags.contains('isButton'), isTrue);
      expect(summary.flags.contains('isFocusable'), isTrue);
      expect(summary.actions.contains('tap'), isTrue);

      handle.dispose();
    });

    testWidgets('select opens and closes semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp(_buildNakedSelect()));

      Tristate triggerExpanded() {
        final root = tester.getSemantics(find.byType(Scaffold));
        final trigger = collectSemanticsNodes(
          root,
          (node) =>
              node.getSemanticsData().flagsCollection.isExpanded !=
              Tristate.none,
        ).single;

        return trigger.getSemanticsData().flagsCollection.isExpanded;
      }

      // Initially closed
      expect(find.text('Select Option'), findsOneWidget);
      expect(find.text('Option 1'), findsNothing);
      expect(triggerExpanded(), Tristate.isFalse);

      // Tap to open
      await tester.tap(find.text('Select Option'));
      await tester.pumpAndSettle();

      // Verify select menu is open
      expect(find.text('Option 1'), findsOneWidget);
      expect(find.text('Option 2'), findsOneWidget);
      expect(find.text('Option 3'), findsOneWidget);
      // Trigger must report the open state to screen readers.
      expect(triggerExpanded(), Tristate.isTrue);

      // Tap outside to close
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Verify select menu is closed
      expect(find.text('Option 1'), findsNothing);
      expect(triggerExpanded(), Tristate.isFalse);

      handle.dispose();
    });

    testWidgets('select item selection semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp(_buildNakedSelect()));

      // Open select
      await tester.tap(find.text('Select Option'));
      await tester.pumpAndSettle();

      // Verify items are selectable
      expect(find.text('Option 1'), findsOneWidget);
      expect(find.text('Option 2'), findsOneWidget);

      // Tap an option
      await tester.tap(find.text('Option 2'));
      await tester.pumpAndSettle();

      // Verify select closed (normal behavior for single select)
      expect(find.text('Option 2'), findsNothing);

      handle.dispose();
    });

    testWidgets('select options expose menu roles and selected state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(_buildNakedSelect(selectedValue: 'option1')),
      );
      await tester.tap(find.text('Select Option'));
      await tester.pumpAndSettle();

      final items = [
        tester.getSemantics(find.text('Option 1')),
        tester.getSemantics(find.text('Option 2')),
        tester.getSemantics(find.text('Option 3')),
      ];
      for (final item in items) {
        expect(item.getSemanticsData().role, SemanticsRole.menuItem);
      }

      SemanticsNode? ancestor = items.first.parent;
      var hasMenuAncestor = false;
      while (ancestor != null) {
        if (ancestor.getSemanticsData().role == SemanticsRole.menu) {
          hasMenuAncestor = true;
          break;
        }
        ancestor = ancestor.parent;
      }
      expect(hasMenuAncestor, isTrue);
      expect(
        items.first.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );

      handle.dispose();
    });

    testWidgets('menu role stays valid while option semantics are faded out', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedSelect<String>(
            onChanged: (_) {},
            builder: (context, state, child) => const Text('Open'),
            overlayBuilder: (context, info) => const FadeTransition(
              opacity: AlwaysStoppedAnimation<double>(0),
              child: NakedSelectOption<String>(
                value: 'option',
                child: Text('Option'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('disabled select semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp(_buildNakedSelect(enabled: false)));

      // Tap should not open the select
      await tester.tap(find.text('Select Option'));
      await tester.pumpAndSettle();

      // Verify select didn't open
      expect(find.text('Option 1'), findsNothing);

      handle.dispose();
    });

    testWidgets('keyboard navigation semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _buildTestApp(
          NakedSelect<String>(
            onChanged: (_) {},
            triggerFocusNode: focusNode,
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

      // Focus the trigger
      focusNode.requestFocus();
      await tester.pump();

      // Verify trigger has keyboard semantics.
      final root = tester.getSemantics(find.byType(Scaffold));
      final triggerSemantics = findSemanticsNode(root, (node) {
        final data = node.getSemanticsData();
        return data.label == 'Select option' &&
            data.flagsCollection.isExpanded != Tristate.none;
      });
      expect(triggerSemantics, isNotNull);
      final triggerData = triggerSemantics!.getSemanticsData();
      expect(triggerData.hasAction(SemanticsAction.tap), isTrue);
      expect(triggerData.flagsCollection.isFocused, Tristate.isTrue);

      // Open with keyboard
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Verify overlay items have proper keyboard semantics
      final appleSemantics = tester.getSemantics(find.text('Apple'));
      expect(
        appleSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      handle.dispose();
      focusNode.dispose();
    });

    testWidgets('focus management semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _buildTestApp(
          NakedSelect<String>(
            value: 'option1',
            onChanged: (value) {},
            triggerFocusNode: focusNode,
            builder: (context, state, child) => const Text('Focusable Select'),
            overlayBuilder: (context, info) => Container(
              width: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NakedSelectOption(value: 'option1', child: Text('Option 1')),
                ],
              ),
            ),
          ),
        ),
      );

      // Request focus
      focusNode.requestFocus();
      await tester.pump();

      // Verify focus
      expect(focusNode.hasFocus, isTrue);

      focusNode.dispose();
      handle.dispose();
    });

    testWidgets('hover semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await tester.pump();

      await tester.pumpWidget(_buildTestApp(_buildNakedSelect()));

      // Hover over trigger
      await mouse.moveTo(tester.getCenter(find.text('Select Option')));
      await tester.pump();

      // Verify trigger responds to hover
      expect(find.text('Select Option'), findsOneWidget);

      await mouse.removePointer();
      handle.dispose();
    });

    testWidgets('select with semantic label', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedSelect<String>(
            value: 'option1',
            onChanged: (value) {},
            semanticLabel: 'Choose an option',
            builder: (context, state, child) => const Text('Labeled Select'),
            overlayBuilder: (context, info) => Container(
              width: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NakedSelectOption(value: 'option1', child: Text('Option 1')),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify select with semantic label
      expect(find.text('Labeled Select'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('select trigger exposes one semantic control node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedSelect<String>(
            value: 'option1',
            onChanged: (value) {},
            semanticLabel: 'Choose an option',
            builder: (context, state, child) => const Text('Labeled Select'),
            overlayBuilder: (context, info) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NakedSelectOption(value: 'option1', child: Text('Option 1')),
              ],
            ),
          ),
        ),
      );

      bool isTriggerControl(SemanticsNode node) {
        final data = node.getSemanticsData();
        return data.flagsCollection.isButton ||
            data.flagsCollection.isExpanded != Tristate.none ||
            data.hasAction(SemanticsAction.tap);
      }

      final root = tester.getSemantics(find.byType(Scaffold));
      final controls = collectSemanticsNodes(root, isTriggerControl);
      expect(controls, hasLength(1));

      final data = controls.single.getSemanticsData();
      expect(data.label, 'Choose an option');
      expect(data.label, isNot(contains('Labeled Select')));
      expect(data.value, 'option1');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isExpanded, Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });

    testWidgets('semanticValue is announced instead of T.toString()', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedSelect<Object>(
            value: Object(),
            onChanged: (_) {},
            semanticValue: 'Apple',
            builder: (context, state, child) => const Text('Fruit'),
            overlayBuilder: (context, info) => const SizedBox.shrink(),
          ),
        ),
      );

      final root = tester.getSemantics(find.byType(Scaffold));
      final triggers = collectSemanticsNodes(
        root,
        (node) =>
            node.getSemanticsData().flagsCollection.isButton ||
            node.getSemanticsData().flagsCollection.isExpanded !=
                Tristate.none,
      );
      expect(triggers, hasLength(1));
      expect(triggers.single.getSemanticsData().value, 'Apple');
      expect(
        triggers.single.getSemanticsData().value,
        isNot(contains('Instance of')),
      );

      handle.dispose();
    });
  });
}
