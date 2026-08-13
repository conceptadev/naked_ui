import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import '../test_helpers.dart';
import 'helpers/builder_state_scope.dart';

void main() {
  group('NakedToggle', () {
    testWidgets('renders child and reflects initial value', (tester) async {
      await tester.pumpMaterialWidget(
        NakedToggle(
          value: false,
          onChanged: (_) {},
          child: const Text('Toggle'),
        ),
      );
      expect(find.text('Toggle'), findsOneWidget);
    });

    testWidgets('toggles on tap', (tester) async {
      bool value = false;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) => NakedToggle(
            value: value,
            onChanged: (v) => setState(() => value = v),
            child: const Text('Toggle'),
          ),
        ),
      );

      await tester.tap(find.text('Toggle'));
      await tester.pump();
      expect(value, isTrue);
    });

    testWidgets('closes via keyboard activation (Space)', (tester) async {
      bool value = false;
      final focusNode = FocusNode();
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) => NakedToggle(
            value: value,
            onChanged: (v) => setState(() => value = v),
            focusNode: focusNode,
            child: const Text('Toggle'),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(value, isTrue);
    });

    testWidgets('disabled does not toggle', (tester) async {
      bool value = false;
      await tester.pumpMaterialWidget(
        NakedToggle(value: value, onChanged: null, child: const Text('Toggle')),
      );

      await tester.tap(find.text('Toggle'));
      await tester.pump();
      expect(value, isFalse);
    });
  });

  group('NakedToggleGroup', () {
    testWidgets('selects one option at a time', (tester) async {
      String? selected = 'a';

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return NakedToggleGroup<String>(
              selectedValue: selected,
              onChanged: (v) => setState(() => selected = v),
              child: Row(
                children: [
                  NakedToggleOption<String>(
                    value: 'a',
                    builder: (context, optionState, child) =>
                        Text(optionState.isSelected ? 'A*' : 'A'),
                  ),
                  NakedToggleOption<String>(
                    value: 'b',
                    builder: (context, optionState, child) =>
                        Text(optionState.isSelected ? 'B*' : 'B'),
                  ),
                ],
              ),
            );
          },
        ),
      );

      expect(find.text('A*'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);

      await tester.tap(find.text('B'));
      await tester.pump();

      expect(selected, 'b');
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B*'), findsOneWidget);
    });

    testWidgets('options invoke the latest group callback', (tester) async {
      var useSecondCallback = false;
      var firstCalls = 0;
      var secondCalls = 0;
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'a',
              onChanged: useSecondCallback
                  ? (_) => secondCalls++
                  : (_) => firstCalls++,
              child: const Row(
                children: [
                  NakedToggleOption<String>(value: 'a', child: Text('A')),
                  NakedToggleOption<String>(value: 'b', child: Text('B')),
                ],
              ),
            );
          },
        ),
      );

      rebuild(() => useSecondCallback = true);
      await tester.pump();
      await tester.tap(find.text('B'));
      await tester.pump();

      expect(firstCalls, 0);
      expect(secondCalls, 1);
    });

    testWidgets('unrelated parent rebuild does not invalidate stable options', (
      tester,
    ) async {
      var parentValue = 0;
      var optionBuilds = 0;
      late StateSetter rebuild;
      final onChanged = (String? _) {};
      final stableOption = NakedToggleOption<String>(
        value: 'a',
        builder: (context, state, child) {
          optionBuilds++;
          return const Text('A');
        },
      );

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              children: [
                Text('$parentValue'),
                NakedToggleGroup<String>(
                  selectedValue: 'a',
                  onChanged: onChanged,
                  child: stableOption,
                ),
              ],
            );
          },
        ),
      );
      final initialBuilds = optionBuilds;

      rebuild(() => parentValue++);
      await tester.pump();

      expect(optionBuilds, initialBuilds);
    });

    testWidgets('disabled group prevents interaction', (tester) async {
      String? selected = 'a';

      await tester.pumpMaterialWidget(
        NakedToggleGroup<String>(
          selectedValue: selected,
          onChanged: null,
          child: Row(
            children: const [
              NakedToggleOption<String>(value: 'a', child: Text('A')),
              NakedToggleOption<String>(value: 'b', child: Text('B')),
            ],
          ),
        ),
      );

      await tester.tap(find.text('B'));
      await tester.pump();
      expect(selected, 'a');
    });

    testWidgets('null callback removes the group from traversal', (
      tester,
    ) async {
      final before = FocusNode(debugLabel: 'before');
      final optionA = FocusNode(debugLabel: 'option A');
      final optionB = FocusNode(debugLabel: 'option B');
      final after = FocusNode(debugLabel: 'after');
      for (final node in [before, optionA, optionB, after]) {
        addTearDown(node.dispose);
      }

      await tester.pumpMaterialWidget(
        Column(
          children: [
            Focus(focusNode: before, child: const Text('Before')),
            NakedToggleGroup<String>(
              selectedValue: 'a',
              onChanged: null,
              child: Row(
                children: [
                  NakedToggleOption<String>(
                    value: 'a',
                    focusNode: optionA,
                    child: const Text('A'),
                  ),
                  NakedToggleOption<String>(
                    value: 'b',
                    focusNode: optionB,
                    child: const Text('B'),
                  ),
                ],
              ),
            ),
            Focus(focusNode: after, child: const Text('After')),
          ],
        ),
      );

      before.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(after.hasPrimaryFocus, isTrue);
      expect(optionA.canRequestFocus, isFalse);
      expect(optionB.canRequestFocus, isFalse);
    });

    for (final disableWithEnabled in [true, false]) {
      final mechanism = disableWithEnabled ? 'enabled' : 'onChanged';
      testWidgets(
        'runtime $mechanism disable removes the stop without stealing focus',
        (tester) async {
          final before = FocusNode(debugLabel: 'before');
          final optionA = FocusNode(debugLabel: 'option A');
          final optionB = FocusNode(debugLabel: 'option B');
          final after = FocusNode(debugLabel: 'after');
          for (final node in [before, optionA, optionB, after]) {
            addTearDown(node.dispose);
          }
          var active = true;
          final proposedValues = <String?>[];
          late StateSetter rebuild;

          await tester.pumpMaterialWidget(
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Column(
                  children: [
                    Focus(focusNode: before, child: const Text('Before')),
                    NakedToggleGroup<String>(
                      selectedValue: 'a',
                      enabled: disableWithEnabled ? active : true,
                      onChanged: disableWithEnabled || active
                          ? proposedValues.add
                          : null,
                      child: Row(
                        children: [
                          NakedToggleOption<String>(
                            value: 'a',
                            focusNode: optionA,
                            child: const Text('A'),
                          ),
                          NakedToggleOption<String>(
                            value: 'b',
                            focusNode: optionB,
                            child: const Text('B'),
                          ),
                        ],
                      ),
                    ),
                    Focus(focusNode: after, child: const Text('After')),
                  ],
                );
              },
            ),
          );

          optionB.requestFocus();
          await tester.pump();
          expect(optionB.hasPrimaryFocus, isTrue);

          rebuild(() => active = false);
          await tester.pump();
          expect(optionA.canRequestFocus, isFalse);
          expect(optionB.canRequestFocus, isFalse);
          expect(optionA.skipTraversal, isTrue);
          expect(optionB.skipTraversal, isTrue);
          expect(before.hasFocus, isFalse);
          expect(after.hasFocus, isFalse);

          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump();
          expect(proposedValues, isEmpty);
          expect(before.hasFocus, isFalse);
          expect(after.hasFocus, isFalse);

          rebuild(() => active = true);
          await tester.pump();
          expect(optionA.skipTraversal, isFalse);
          expect(optionB.skipTraversal, isTrue);

          after.requestFocus();
          await tester.pump();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pump();
          expect(optionA.hasPrimaryFocus, isTrue);
        },
      );
    }

    testWidgets('tapping already selected option is a no-op', (tester) async {
      String? selected = 'a';
      var calls = 0;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return NakedToggleGroup<String>(
              selectedValue: selected,
              onChanged: (v) {
                calls++;
                setState(() => selected = v);
              },
              child: Row(
                children: const [
                  NakedToggleOption<String>(value: 'a', child: Text('A')),
                  NakedToggleOption<String>(value: 'b', child: Text('B')),
                ],
              ),
            );
          },
        ),
      );

      expect(selected, 'a');
      await tester.tap(find.text('A'));
      await tester.pump();
      expect(
        calls,
        0,
        reason: 'onChanged should not fire when selecting the same value',
      );
      expect(selected, 'a');
    });

    testWidgets('disabled option cannot be selected (group enabled)', (
      tester,
    ) async {
      String? selected = 'a';

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return NakedToggleGroup<String>(
              selectedValue: selected,
              onChanged: (v) => setState(() => selected = v),
              child: Row(
                children: const [
                  NakedToggleOption<String>(value: 'a', child: Text('A')),
                  NakedToggleOption<String>(
                    value: 'b',
                    child: Text('B'),
                    enabled: false,
                  ),
                ],
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('B'));
      await tester.pump();
      expect(selected, 'a');
    });

    testWidgets('keyboard activation selects focused option', (tester) async {
      String? selected = 'a';
      final bFocus = FocusNode();

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return NakedToggleGroup<String>(
              selectedValue: selected,
              onChanged: (v) => setState(() => selected = v),
              child: Row(
                children: [
                  const NakedToggleOption<String>(value: 'a', child: Text('A')),
                  NakedToggleOption<String>(
                    value: 'b',
                    focusNode: bFocus,
                    child: const Text('B'),
                  ),
                ],
              ),
            );
          },
        ),
      );

      bFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(selected, 'b');
    });

    testWidgets('Enter, Space, and pointer each emit exactly one proposal', (
      tester,
    ) async {
      final bFocus = FocusNode(debugLabel: 'option B');
      addTearDown(bFocus.dispose);
      final proposedValues = <String?>[];

      await tester.pumpMaterialWidget(
        NakedToggleGroup<String>(
          selectedValue: 'a',
          onChanged: proposedValues.add,
          child: Row(
            children: [
              const NakedToggleOption<String>(
                value: 'a',
                enableFeedback: false,
                child: Text('A'),
              ),
              NakedToggleOption<String>(
                value: 'b',
                enableFeedback: false,
                focusNode: bFocus,
                child: const Text('B'),
              ),
            ],
          ),
        ),
      );

      bFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(proposedValues, ['b']);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(proposedValues, ['b', 'b']);

      await tester.tap(find.text('B'));
      await tester.pump();
      expect(proposedValues, ['b', 'b', 'b']);
    });

    testWidgets('contributes one Tab stop and Tab exits the group', (
      tester,
    ) async {
      final before = FocusNode(debugLabel: 'before');
      final optionA = FocusNode(debugLabel: 'option A');
      final optionB = FocusNode(debugLabel: 'option B');
      final after = FocusNode(debugLabel: 'after');
      addTearDown(before.dispose);
      addTearDown(optionA.dispose);
      addTearDown(optionB.dispose);
      addTearDown(after.dispose);

      await tester.pumpMaterialWidget(
        Column(
          children: [
            Focus(focusNode: before, child: const Text('Before')),
            NakedToggleGroup<String>(
              selectedValue: 'a',
              onChanged: (_) {},
              child: Row(
                children: [
                  NakedToggleOption<String>(
                    value: 'a',
                    focusNode: optionA,
                    child: const Text('A'),
                  ),
                  NakedToggleOption<String>(
                    value: 'b',
                    focusNode: optionB,
                    child: const Text('B'),
                  ),
                ],
              ),
            ),
            Focus(focusNode: after, child: const Text('After')),
          ],
        ),
      );

      before.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(optionA.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);
      expect(optionB.hasFocus, isFalse);
    });

    testWidgets('option descendants do not add a Tab stop', (tester) async {
      final before = FocusNode(debugLabel: 'before');
      final option = FocusNode(debugLabel: 'option');
      final descendant = FocusNode(debugLabel: 'option descendant');
      final after = FocusNode(debugLabel: 'after');
      for (final node in [before, option, descendant, after]) {
        addTearDown(node.dispose);
      }

      await tester.pumpMaterialWidget(
        Column(
          children: [
            Focus(focusNode: before, child: const Text('Before')),
            NakedToggleGroup<String>(
              selectedValue: 'a',
              onChanged: (_) {},
              child: NakedToggleOption<String>(
                value: 'a',
                focusNode: option,
                child: Focus(
                  focusNode: descendant,
                  child: const Text('Focusable content'),
                ),
              ),
            ),
            Focus(focusNode: after, child: const Text('After')),
          ],
        ),
      );

      before.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(option.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);
      expect(descendant.hasFocus, isFalse);
    });

    testWidgets('enters on the selected enabled option', (tester) async {
      final before = FocusNode(debugLabel: 'before');
      final optionA = FocusNode(debugLabel: 'option A');
      final optionB = FocusNode(debugLabel: 'option B');
      addTearDown(before.dispose);
      addTearDown(optionA.dispose);
      addTearDown(optionB.dispose);

      await tester.pumpMaterialWidget(
        Column(
          children: [
            Focus(focusNode: before, child: const Text('Before')),
            NakedToggleGroup<String>(
              selectedValue: 'b',
              onChanged: (_) {},
              child: Row(
                children: [
                  NakedToggleOption<String>(
                    value: 'a',
                    focusNode: optionA,
                    child: const Text('A'),
                  ),
                  NakedToggleOption<String>(
                    value: 'b',
                    focusNode: optionB,
                    child: const Text('B'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      before.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(optionB.hasPrimaryFocus, isTrue);
      expect(optionA.hasFocus, isFalse);
    });

    testWidgets('arrows move focus only and last focus wins on re-entry', (
      tester,
    ) async {
      final before = FocusNode(debugLabel: 'before');
      final optionA = FocusNode(debugLabel: 'option A');
      final optionB = FocusNode(debugLabel: 'option B');
      final optionC = FocusNode(debugLabel: 'option C');
      final after = FocusNode(debugLabel: 'after');
      for (final node in [before, optionA, optionB, optionC, after]) {
        addTearDown(node.dispose);
      }
      String? selected = 'a';
      final proposedValues = <String?>[];
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              children: [
                Focus(focusNode: before, child: const Text('Before')),
                NakedToggleGroup<String>(
                  selectedValue: selected,
                  onChanged: proposedValues.add,
                  child: Row(
                    children: [
                      NakedToggleOption<String>(
                        value: 'a',
                        focusNode: optionA,
                        child: const Text('A'),
                      ),
                      NakedToggleOption<String>(
                        value: 'b',
                        focusNode: optionB,
                        child: const Text('B'),
                      ),
                      NakedToggleOption<String>(
                        value: 'c',
                        focusNode: optionC,
                        child: const Text('C'),
                      ),
                    ],
                  ),
                ),
                Focus(focusNode: after, child: const Text('After')),
              ],
            );
          },
        ),
      );

      before.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(optionA.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(optionB.hasPrimaryFocus, isTrue);
      expect(selected, 'a');
      expect(proposedValues, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(proposedValues, ['b']);
      expect(selected, 'a', reason: 'selection remains controlled by the host');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);

      rebuild(() => selected = 'c');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(optionB.hasPrimaryFocus, isTrue);
    });

    testWidgets('skips disabled options and honors Home, End, and loop', (
      tester,
    ) async {
      final optionA = FocusNode(debugLabel: 'option A');
      final optionB = FocusNode(debugLabel: 'option B');
      final optionC = FocusNode(debugLabel: 'option C');
      for (final node in [optionA, optionB, optionC]) {
        addTearDown(node.dispose);
      }
      var loop = true;
      final proposedValues = <String?>[];
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'a',
              onChanged: proposedValues.add,
              loop: loop,
              child: Row(
                children: [
                  NakedToggleOption<String>(
                    value: 'a',
                    focusNode: optionA,
                    child: const Text('A'),
                  ),
                  NakedToggleOption<String>(
                    value: 'b',
                    enabled: false,
                    focusNode: optionB,
                    child: const Text('B'),
                  ),
                  NakedToggleOption<String>(
                    value: 'c',
                    focusNode: optionC,
                    child: const Text('C'),
                  ),
                ],
              ),
            );
          },
        ),
      );

      optionA.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(optionC.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(optionA.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(optionC.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(optionA.hasPrimaryFocus, isTrue);

      rebuild(() => loop = false);
      await tester.pump();
      optionC.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(optionC.hasPrimaryFocus, isTrue);
      expect(optionB.hasFocus, isFalse);
      expect(proposedValues, isEmpty);
    });

    testWidgets('vertical groups claim only Up and Down', (tester) async {
      final optionA = FocusNode(debugLabel: 'option A');
      final optionB = FocusNode(debugLabel: 'option B');
      final optionC = FocusNode(debugLabel: 'option C');
      for (final node in [optionA, optionB, optionC]) {
        addTearDown(node.dispose);
      }
      var orthogonalCalls = 0;

      await tester.pumpMaterialWidget(
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              orthogonalCalls++;
            },
          },
          child: NakedToggleGroup<String>(
            selectedValue: 'a',
            onChanged: (_) {},
            orientation: Axis.vertical,
            child: Column(
              children: [
                NakedToggleOption<String>(
                  value: 'a',
                  focusNode: optionA,
                  child: const Text('A'),
                ),
                NakedToggleOption<String>(
                  value: 'b',
                  enabled: false,
                  focusNode: optionB,
                  child: const Text('B'),
                ),
                NakedToggleOption<String>(
                  value: 'c',
                  focusNode: optionC,
                  child: const Text('C'),
                ),
              ],
            ),
          ),
        ),
      );

      optionA.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(orthogonalCalls, 1);
      expect(optionA.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(optionC.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(optionA.hasPrimaryFocus, isTrue);
    });

    testWidgets('horizontal arrows follow visual direction in RTL', (
      tester,
    ) async {
      final optionA = FocusNode(debugLabel: 'option A');
      final optionB = FocusNode(debugLabel: 'option B');
      final optionC = FocusNode(debugLabel: 'option C');
      for (final node in [optionA, optionB, optionC]) {
        addTearDown(node.dispose);
      }

      await tester.pumpMaterialWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: NakedToggleGroup<String>(
            selectedValue: 'b',
            onChanged: (_) {},
            child: Row(
              children: [
                NakedToggleOption<String>(
                  value: 'a',
                  focusNode: optionA,
                  child: const Text('A'),
                ),
                NakedToggleOption<String>(
                  value: 'b',
                  focusNode: optionB,
                  child: const Text('B'),
                ),
                NakedToggleOption<String>(
                  value: 'c',
                  focusNode: optionC,
                  child: const Text('C'),
                ),
              ],
            ),
          ),
        ),
      );

      optionB.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(optionA.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(optionB.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(optionC.hasPrimaryFocus, isTrue);
    });

    testWidgets('updates arrow bindings when orientation changes at runtime', (
      tester,
    ) async {
      final nodes = {
        for (final value in ['a', 'b', 'c'])
          value: FocusNode(debugLabel: 'option $value'),
      };
      for (final node in nodes.values) {
        addTearDown(node.dispose);
      }
      var orientation = Axis.horizontal;
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'b',
              onChanged: (_) {},
              orientation: orientation,
              child: Flex(
                direction: orientation,
                children: [
                  for (final value in ['a', 'b', 'c'])
                    NakedToggleOption<String>(
                      value: value,
                      focusNode: nodes[value],
                      child: Text(value.toUpperCase()),
                    ),
                ],
              ),
            );
          },
        ),
      );

      nodes['b']!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(nodes['c']!.hasPrimaryFocus, isTrue);

      rebuild(() => orientation = Axis.vertical);
      await tester.pump();
      nodes['b']!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(nodes['b']!.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(nodes['c']!.hasPrimaryFocus, isTrue);
    });

    testWidgets('updates horizontal direction at runtime', (tester) async {
      final nodes = {
        for (final value in ['a', 'b', 'c'])
          value: FocusNode(debugLabel: 'option $value'),
      };
      for (final node in nodes.values) {
        addTearDown(node.dispose);
      }
      var textDirection = TextDirection.ltr;
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Directionality(
              textDirection: textDirection,
              child: NakedToggleGroup<String>(
                selectedValue: 'b',
                onChanged: (_) {},
                child: Row(
                  children: [
                    for (final value in ['a', 'b', 'c'])
                      NakedToggleOption<String>(
                        value: value,
                        focusNode: nodes[value],
                        child: Text(value.toUpperCase()),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      nodes['b']!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(nodes['c']!.hasPrimaryFocus, isTrue);

      rebuild(() => textDirection = TextDirection.rtl);
      await tester.pump();
      nodes['b']!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(nodes['a']!.hasPrimaryFocus, isTrue);
    });

    testWidgets(
      'falls back to first enabled and disappears when all disabled',
      (tester) async {
        final before = FocusNode(debugLabel: 'before');
        final optionA = FocusNode(debugLabel: 'option A');
        final optionB = FocusNode(debugLabel: 'option B');
        final optionC = FocusNode(debugLabel: 'option C');
        final after = FocusNode(debugLabel: 'after');
        for (final node in [before, optionA, optionB, optionC, after]) {
          addTearDown(node.dispose);
        }
        var allDisabled = false;
        late StateSetter rebuild;

        await tester.pumpMaterialWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Column(
                children: [
                  Focus(focusNode: before, child: const Text('Before')),
                  NakedToggleGroup<String>(
                    selectedValue: 'b',
                    onChanged: (_) {},
                    child: Row(
                      children: [
                        NakedToggleOption<String>(
                          value: 'a',
                          enabled: !allDisabled,
                          focusNode: optionA,
                          child: const Text('A'),
                        ),
                        NakedToggleOption<String>(
                          value: 'b',
                          enabled: false,
                          focusNode: optionB,
                          child: const Text('B'),
                        ),
                        NakedToggleOption<String>(
                          value: 'c',
                          enabled: false,
                          focusNode: optionC,
                          child: const Text('C'),
                        ),
                      ],
                    ),
                  ),
                  Focus(focusNode: after, child: const Text('After')),
                ],
              );
            },
          ),
        );

        before.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(optionA.hasPrimaryFocus, isTrue);

        after.requestFocus();
        await tester.pump();
        rebuild(() => allDisabled = true);
        await tester.pump();
        before.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(after.hasPrimaryFocus, isTrue);
        expect(optionA.canRequestFocus, isFalse);
        expect(optionB.canRequestFocus, isFalse);
        expect(optionC.canRequestFocus, isFalse);
      },
    );

    testWidgets('recomputes keyed visual order after reorder', (tester) async {
      final nodes = {
        for (final value in ['a', 'b', 'c', 'd'])
          value: FocusNode(debugLabel: 'option $value'),
      };
      for (final node in nodes.values) {
        addTearDown(node.dispose);
      }
      var values = ['a', 'b', 'c'];
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'a',
              onChanged: (_) {},
              child: Row(
                children: [
                  for (final value in values)
                    NakedToggleOption<String>(
                      key: ValueKey(value),
                      value: value,
                      focusNode: nodes[value],
                      child: Text(value.toUpperCase()),
                    ),
                ],
              ),
            );
          },
        ),
      );

      nodes['b']!.requestFocus();
      await tester.pump();
      rebuild(() => values = ['b', 'c', 'a']);
      await tester.pump();
      expect(nodes['b']!.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(nodes['c']));

      rebuild(() => values = ['b', 'd', 'c', 'a']);
      await tester.pump();
      nodes['b']!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(nodes['d']));
    });

    testWidgets('refreshes visual order when only a stateful child reorders', (
      tester,
    ) async {
      final reversed = ValueNotifier<bool>(false);
      addTearDown(reversed.dispose);
      final optionA = FocusNode(debugLabel: 'option A');
      final optionB = FocusNode(debugLabel: 'option B');
      addTearDown(optionA.dispose);
      addTearDown(optionB.dispose);
      final widgetA = NakedToggleOption<String>(
        key: const ValueKey('a'),
        value: 'a',
        focusNode: optionA,
        child: const SizedBox(width: 40, height: 40, child: Text('A')),
      );
      final widgetB = NakedToggleOption<String>(
        key: const ValueKey('b'),
        value: 'b',
        focusNode: optionB,
        child: const SizedBox(width: 40, height: 40, child: Text('B')),
      );

      await tester.pumpMaterialWidget(
        NakedToggleGroup<String>(
          selectedValue: 'a',
          onChanged: (_) {},
          loop: false,
          child: ValueListenableBuilder<bool>(
            valueListenable: reversed,
            builder: (context, isReversed, child) => Row(
              children: isReversed ? [widgetB, widgetA] : [widgetA, widgetB],
            ),
          ),
        ),
      );

      optionB.requestFocus();
      await tester.pump();
      await tester.pump();

      reversed.value = true;
      await tester.pump();
      await tester.pump();
      expect(
        tester.getCenter(find.text('B')).dx,
        lessThan(tester.getCenter(find.text('A')).dx),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(optionA.hasPrimaryFocus, isTrue);
    });

    for (final orientation in Axis.values) {
      for (final textDirection in TextDirection.values) {
        testWidgets('follows wrapped ${orientation.name} visual order in '
            '${textDirection.name}', (tester) async {
          final nodes = {
            for (final value in ['a', 'b', 'c', 'd'])
              value: FocusNode(debugLabel: 'option $value'),
          };
          for (final node in nodes.values) {
            addTearDown(node.dispose);
          }

          await tester.pumpMaterialWidget(
            Directionality(
              textDirection: textDirection,
              child: SizedBox(
                width: orientation == Axis.horizontal ? 110 : 120,
                height: orientation == Axis.horizontal ? 80 : 65,
                child: NakedToggleGroup<String>(
                  selectedValue: 'a',
                  onChanged: (_) {},
                  orientation: orientation,
                  child: Wrap(
                    direction: orientation,
                    children: [
                      for (final value in ['a', 'b', 'c', 'd'])
                        NakedToggleOption<String>(
                          value: value,
                          focusNode: nodes[value],
                          child: SizedBox(
                            width: 50,
                            height: 30,
                            child: Text(value.toUpperCase()),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );

          nodes['a']!.requestFocus();
          await tester.pump();
          final forwardKey = switch ((orientation, textDirection)) {
            (Axis.vertical, _) => LogicalKeyboardKey.arrowDown,
            (Axis.horizontal, TextDirection.ltr) =>
              LogicalKeyboardKey.arrowRight,
            (Axis.horizontal, TextDirection.rtl) =>
              LogicalKeyboardKey.arrowLeft,
          };
          await tester.sendKeyEvent(forwardKey);
          await tester.pump();
          expect(FocusManager.instance.primaryFocus, same(nodes['b']));
          await tester.sendKeyEvent(forwardKey);
          await tester.pump();
          expect(FocusManager.instance.primaryFocus, same(nodes['c']));
        });
      }
    }

    testWidgets('repairs focused removal to successor then predecessor', (
      tester,
    ) async {
      final nodes = {
        for (final value in ['a', 'b', 'c'])
          value: FocusNode(debugLabel: 'option $value'),
      };
      for (final node in nodes.values) {
        addTearDown(node.dispose);
      }
      var values = ['a', 'b', 'c'];
      final enabledValues = {'a', 'b', 'c'};
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'a',
              onChanged: (_) {},
              child: Row(
                children: [
                  for (final value in values)
                    NakedToggleOption<String>(
                      key: ValueKey(value),
                      value: value,
                      enabled: enabledValues.contains(value),
                      focusNode: nodes[value],
                      child: Text(value.toUpperCase()),
                    ),
                ],
              ),
            );
          },
        ),
      );

      nodes['b']!.requestFocus();
      await tester.pump();
      rebuild(() => values = ['a', 'c']);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(nodes['c']));

      rebuild(() => enabledValues.remove('c'));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(nodes['a']));

      final listener = () {};
      expect(() => nodes['b']!.addListener(listener), returnsNormally);
      nodes['b']!.removeListener(listener);
    });

    testWidgets('repairs removal from the final visual order exactly once', (
      tester,
    ) async {
      final nodes = {
        for (final value in ['a', 'b', 'c'])
          value: FocusNode(debugLabel: 'option $value'),
      };
      for (final node in nodes.values) {
        addTearDown(node.dispose);
      }
      var values = ['a', 'b', 'c'];
      final focusChanges = <String>[];
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'a',
              onChanged: (_) {},
              child: Row(
                children: [
                  for (final value in values)
                    NakedToggleOption<String>(
                      key: ValueKey(value),
                      value: value,
                      focusNode: nodes[value],
                      onFocusChange: (focused) {
                        focusChanges.add('$value:$focused');
                      },
                      child: Text(value.toUpperCase()),
                    ),
                ],
              ),
            );
          },
        ),
      );

      nodes['b']!.requestFocus();
      await tester.pump();
      focusChanges.clear();

      rebuild(() => values = ['c', 'a']);
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, same(nodes['a']));
      expect(focusChanges, ['a:true']);
    });

    testWidgets('repairs disable from the final visual order', (tester) async {
      final nodes = {
        for (final value in ['a', 'b', 'c'])
          value: FocusNode(debugLabel: 'option $value'),
      };
      for (final node in nodes.values) {
        addTearDown(node.dispose);
      }
      var values = ['a', 'b', 'c'];
      final enabledValues = {'a', 'b', 'c'};
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'c',
              onChanged: (_) {},
              child: Row(
                children: [
                  for (final value in values)
                    NakedToggleOption<String>(
                      key: ValueKey(value),
                      value: value,
                      enabled: enabledValues.contains(value),
                      focusNode: nodes[value],
                      child: Text(value.toUpperCase()),
                    ),
                ],
              ),
            );
          },
        ),
      );

      nodes['b']!.requestFocus();
      await tester.pump();

      rebuild(() {
        enabledValues.remove('b');
        values = ['c', 'a', 'b'];
      });
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, same(nodes['a']));
    });

    testWidgets('same-turn outside focus and removal does not steal focus', (
      tester,
    ) async {
      final nodes = {
        for (final value in ['a', 'b', 'c'])
          value: FocusNode(debugLabel: 'option $value'),
      };
      final after = FocusNode(debugLabel: 'after');
      for (final node in [...nodes.values, after]) {
        addTearDown(node.dispose);
      }
      var values = ['a', 'b', 'c'];
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              children: [
                NakedToggleGroup<String>(
                  selectedValue: 'a',
                  onChanged: (_) {},
                  child: Row(
                    children: [
                      for (final value in values)
                        NakedToggleOption<String>(
                          key: ValueKey(value),
                          value: value,
                          focusNode: nodes[value],
                          child: Text(value.toUpperCase()),
                        ),
                    ],
                  ),
                ),
                Focus(focusNode: after, child: const Text('After')),
              ],
            );
          },
        ),
      );

      nodes['b']!.requestFocus();
      await tester.pump();
      expect(nodes['b']!.hasPrimaryFocus, isTrue);

      after.requestFocus();
      rebuild(() => values = ['a', 'c']);
      await tester.pump();

      expect(after.hasPrimaryFocus, isTrue);
    });

    testWidgets('retargets while outside without stealing page focus', (
      tester,
    ) async {
      final optionA = FocusNode(debugLabel: 'option A');
      final optionB = FocusNode(debugLabel: 'option B');
      final optionC = FocusNode(debugLabel: 'option C');
      final after = FocusNode(debugLabel: 'after');
      for (final node in [optionA, optionB, optionC, after]) {
        addTearDown(node.dispose);
      }
      String? selected = 'a';
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              children: [
                NakedToggleGroup<String>(
                  selectedValue: selected,
                  onChanged: (_) {},
                  child: Row(
                    children: [
                      NakedToggleOption<String>(
                        value: 'a',
                        focusNode: optionA,
                        child: const Text('A'),
                      ),
                      NakedToggleOption<String>(
                        value: 'b',
                        focusNode: optionB,
                        child: const Text('B'),
                      ),
                      NakedToggleOption<String>(
                        value: 'c',
                        focusNode: optionC,
                        child: const Text('C'),
                      ),
                    ],
                  ),
                ),
                Focus(focusNode: after, child: const Text('After')),
              ],
            );
          },
        ),
      );

      after.requestFocus();
      await tester.pump();
      rebuild(() => selected = 'c');
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(optionC.hasPrimaryFocus, isTrue);

      after.requestFocus();
      await tester.pump();
      rebuild(() => selected = 'b');
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        optionC.hasPrimaryFocus,
        isTrue,
        reason: 'last still-valid focus has priority over selection',
      );
    });

    testWidgets('preserves focused keyed option when moved between groups', (
      tester,
    ) async {
      final movingOptionKey = GlobalKey();
      final moving = FocusNode(debugLabel: 'moving option');
      final firstSibling = FocusNode(debugLabel: 'first group sibling');
      final secondSibling = FocusNode(debugLabel: 'second group sibling');
      for (final node in [moving, firstSibling, secondSibling]) {
        addTearDown(node.dispose);
      }
      final movingOption = NakedToggleOption<String>(
        key: movingOptionKey,
        value: 'moving',
        focusNode: moving,
        child: const Text('Moving'),
      );
      var inFirstGroup = true;
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              children: [
                NakedToggleGroup<String>(
                  selectedValue: inFirstGroup ? 'moving' : 'first',
                  onChanged: (_) {},
                  child: Row(
                    children: [
                      if (inFirstGroup) movingOption,
                      NakedToggleOption<String>(
                        value: 'first',
                        focusNode: firstSibling,
                        child: const Text('First'),
                      ),
                    ],
                  ),
                ),
                NakedToggleGroup<String>(
                  selectedValue: 'second',
                  onChanged: (_) {},
                  child: Row(
                    children: [
                      if (!inFirstGroup) movingOption,
                      NakedToggleOption<String>(
                        value: 'second',
                        focusNode: secondSibling,
                        child: const Text('Second'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      moving.requestFocus();
      await tester.pump();
      expect(moving.hasPrimaryFocus, isTrue);

      rebuild(() => inFirstGroup = false);
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, same(moving));
      expect(firstSibling.hasFocus, isFalse);
      expect(moving.skipTraversal, isFalse);
      expect(secondSibling.skipTraversal, isTrue);
    });

    testWidgets('hands focus across caller-owned node swaps', (tester) async {
      final oldNode = FocusNode(debugLabel: 'old option node');
      final newNode = FocusNode(debugLabel: 'new option node');
      addTearDown(oldNode.dispose);
      addTearDown(newNode.dispose);
      var focusNode = oldNode;
      var showGroup = true;
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return showGroup
                ? NakedToggleGroup<String>(
                    selectedValue: 'a',
                    onChanged: (_) {},
                    child: NakedToggleOption<String>(
                      value: 'a',
                      focusNode: focusNode,
                      child: const Text('A'),
                    ),
                  )
                : const SizedBox();
          },
        ),
      );

      oldNode.requestFocus();
      await tester.pump();
      rebuild(() => focusNode = newNode);
      await tester.pump();
      expect(newNode.hasPrimaryFocus, isTrue);

      rebuild(() => showGroup = false);
      await tester.pump();
      final listener = () {};
      expect(() => oldNode.addListener(listener), returnsNormally);
      oldNode.removeListener(listener);
      expect(() => newNode.addListener(listener), returnsNormally);
      newNode.removeListener(listener);
    });

    testWidgets('restores caller-owned focus node properties', (tester) async {
      final oldNode = FocusNode(
        debugLabel: 'old option node',
        canRequestFocus: false,
        skipTraversal: true,
      );
      final newNode = FocusNode(
        debugLabel: 'new option node',
        canRequestFocus: true,
        skipTraversal: true,
      );
      addTearDown(oldNode.dispose);
      addTearDown(newNode.dispose);
      var focusNode = oldNode;
      var showGroup = true;
      late StateSetter rebuild;

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return showGroup
                ? NakedToggleGroup<String>(
                    selectedValue: 'a',
                    onChanged: (_) {},
                    child: NakedToggleOption<String>(
                      value: 'a',
                      focusNode: focusNode,
                      child: const Text('A'),
                    ),
                  )
                : const SizedBox();
          },
        ),
      );

      expect(oldNode.canRequestFocus, isTrue);
      expect(oldNode.skipTraversal, isFalse);

      rebuild(() => focusNode = newNode);
      await tester.pump();
      expect(oldNode.canRequestFocus, isFalse);
      expect(oldNode.skipTraversal, isTrue);
      expect(newNode.canRequestFocus, isTrue);
      expect(newNode.skipTraversal, isFalse);

      rebuild(() => showGroup = false);
      await tester.pump();
      expect(newNode.canRequestFocus, isTrue);
      expect(newNode.skipTraversal, isTrue);
    });

    testWidgets('autofocus targets the requesting enabled option', (
      tester,
    ) async {
      final optionA = FocusNode(debugLabel: 'option A');
      final optionB = FocusNode(debugLabel: 'option B');
      addTearDown(optionA.dispose);
      addTearDown(optionB.dispose);

      await tester.pumpMaterialWidget(
        NakedToggleGroup<String>(
          selectedValue: 'b',
          onChanged: (_) {},
          child: Row(
            children: [
              NakedToggleOption<String>(
                value: 'a',
                autofocus: true,
                focusNode: optionA,
                child: const Text('A'),
              ),
              NakedToggleOption<String>(
                value: 'b',
                focusNode: optionB,
                child: const Text('B'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(optionA.hasPrimaryFocus, isTrue);
      expect(optionB.hasFocus, isFalse);
    });

    testWidgets('disabled autofocus does not focus another option', (
      tester,
    ) async {
      final optionA = FocusNode(debugLabel: 'disabled option A');
      final optionB = FocusNode(debugLabel: 'selected option B');
      addTearDown(optionA.dispose);
      addTearDown(optionB.dispose);

      await tester.pumpMaterialWidget(
        NakedToggleGroup<String>(
          selectedValue: 'b',
          onChanged: (_) {},
          child: Row(
            children: [
              NakedToggleOption<String>(
                value: 'a',
                enabled: false,
                autofocus: true,
                focusNode: optionA,
                child: const Text('A'),
              ),
              NakedToggleOption<String>(
                value: 'b',
                focusNode: optionB,
                child: const Text('B'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(optionA.hasFocus, isFalse);
      expect(optionB.hasFocus, isFalse);
    });

    testWidgets('preserves option builder and interaction callbacks', (
      tester,
    ) async {
      const optionKey = ValueKey('option-b');
      final optionFocus = FocusNode(debugLabel: 'option B');
      addTearDown(optionFocus.dispose);
      final focusChanges = <bool>[];
      final hoverChanges = <bool>[];
      final pressChanges = <bool>[];
      late NakedToggleOptionState<String> latestState;

      await tester.pumpMaterialWidget(
        NakedToggleGroup<String>(
          selectedValue: 'a',
          onChanged: (_) {},
          child: NakedToggleOption<String>(
            key: optionKey,
            value: 'b',
            focusNode: optionFocus,
            onFocusChange: focusChanges.add,
            onHoverChange: hoverChanges.add,
            onPressChange: pressChanges.add,
            builder: (context, state, child) {
              latestState = state;
              return const SizedBox(width: 80, height: 40);
            },
          ),
        ),
      );

      expect(latestState.value, 'b');
      expect(latestState.isSelected, isFalse);

      optionFocus.requestFocus();
      await tester.pump();
      expect(focusChanges, [true]);
      expect(latestState.isFocused, isTrue);

      await tester.simulateHover(optionKey);
      expect(hoverChanges, [true, false]);

      await tester.simulatePress(optionKey);
      expect(pressChanges, [true, false]);
    });

    testWidgets('reports disabled cleanup in hover press focus order', (
      tester,
    ) async {
      const optionKey = ValueKey('ordered-cleanup-option');
      final optionFocus = FocusNode(debugLabel: 'ordered cleanup option');
      addTearDown(optionFocus.dispose);
      var optionEnabled = true;
      late StateSetter rebuild;
      final cleanupOrder = <String>[];
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      addTearDown(mouse.removePointer);

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'a',
              onChanged: (_) {},
              child: NakedToggleOption<String>(
                key: optionKey,
                value: 'a',
                enabled: optionEnabled,
                focusNode: optionFocus,
                onHoverChange: (value) {
                  if (!value) cleanupOrder.add('hover');
                },
                onPressChange: (value) {
                  if (!value) cleanupOrder.add('press');
                },
                onFocusChange: (value) {
                  if (!value) cleanupOrder.add('focus');
                },
                child: const SizedBox(width: 80, height: 40),
              ),
            );
          },
        ),
      );

      await mouse.moveTo(tester.getCenter(find.byKey(optionKey)));
      optionFocus.requestFocus();
      final press = await tester.startGesture(
        tester.getCenter(find.byKey(optionKey)),
      );
      await tester.pump();

      rebuild(() => optionEnabled = false);
      await tester.pump();

      expect(cleanupOrder, ['hover', 'press', 'focus']);
      await press.up();
    });

    testWidgets('clears hover state on every effective-disable path', (
      tester,
    ) async {
      const optionKey = ValueKey('hover-option');
      var optionEnabled = true;
      var groupEnabled = true;
      var callbackEnabled = true;
      late StateSetter rebuild;
      late NakedToggleOptionState<String> latestState;
      final hoverChanges = <bool>[];
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      addTearDown(mouse.removePointer);

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'a',
              enabled: groupEnabled,
              onChanged: callbackEnabled ? (_) {} : null,
              child: NakedToggleOption<String>(
                key: optionKey,
                value: 'a',
                enabled: optionEnabled,
                onHoverChange: (value) {
                  hoverChanges.add(value);
                  if (!value) rebuild(() {});
                },
                builder: (context, state, child) {
                  latestState = state;
                  return const SizedBox(width: 80, height: 40);
                },
              ),
            );
          },
        ),
      );

      await mouse.moveTo(tester.getCenter(find.byKey(optionKey)));
      await tester.pump();
      expect(latestState.isHovered, isTrue);
      expect(hoverChanges, [true]);

      rebuild(() => optionEnabled = false);
      await tester.pump();
      expect(latestState.isDisabled, isTrue);
      expect(latestState.isHovered, isFalse);
      expect(hoverChanges, [true, false]);

      await mouse.moveTo(const Offset(-100, -100));
      rebuild(() => optionEnabled = true);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.byKey(optionKey)));
      await tester.pump();
      expect(latestState.isHovered, isTrue);

      rebuild(() => groupEnabled = false);
      await tester.pump();
      expect(latestState.isDisabled, isTrue);
      expect(latestState.isHovered, isFalse);
      expect(hoverChanges, [true, false, true, false]);

      await mouse.moveTo(const Offset(-100, -100));
      rebuild(() => groupEnabled = true);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.byKey(optionKey)));
      await tester.pump();
      expect(latestState.isHovered, isTrue);

      rebuild(() => callbackEnabled = false);
      await tester.pump();
      expect(latestState.isDisabled, isTrue);
      expect(latestState.isHovered, isFalse);
      expect(hoverChanges, [true, false, true, false, true, false]);
    });

    testWidgets('clears pressed state on every effective-disable path', (
      tester,
    ) async {
      const optionKey = ValueKey('pressed-option');
      var optionEnabled = true;
      var groupEnabled = true;
      var callbackEnabled = true;
      late StateSetter rebuild;
      late NakedToggleOptionState<String> latestState;
      final pressChanges = <bool>[];

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'a',
              enabled: groupEnabled,
              onChanged: callbackEnabled ? (_) {} : null,
              child: NakedToggleOption<String>(
                key: optionKey,
                value: 'a',
                enabled: optionEnabled,
                onPressChange: (value) {
                  pressChanges.add(value);
                  if (!value) rebuild(() {});
                },
                builder: (context, state, child) {
                  latestState = state;
                  return const SizedBox(width: 80, height: 40);
                },
              ),
            );
          },
        ),
      );

      Future<void> pressThenDisable(
        VoidCallback disable, {
        required int expectedPresses,
      }) async {
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(optionKey)),
        );
        await tester.pump();
        expect(latestState.isPressed, isTrue);

        rebuild(disable);
        await tester.pump();
        expect(latestState.isDisabled, isTrue);
        expect(latestState.isPressed, isFalse);
        final expectedChanges = <bool>[
          for (var i = 0; i < expectedPresses; i++) ...[true, false],
        ];
        expect(pressChanges, expectedChanges);

        await gesture.up();
        await tester.pump();
        expect(pressChanges, expectedChanges);
      }

      await pressThenDisable(() => optionEnabled = false, expectedPresses: 1);
      rebuild(() => optionEnabled = true);
      await tester.pump();

      await pressThenDisable(() => groupEnabled = false, expectedPresses: 2);
      rebuild(() => groupEnabled = true);
      await tester.pump();

      await pressThenDisable(() => callbackEnabled = false, expectedPresses: 3);
    });

    testWidgets('reports one focus loss on every effective-disable path', (
      tester,
    ) async {
      final optionFocus = FocusNode(debugLabel: 'option B');
      addTearDown(optionFocus.dispose);
      var optionEnabled = true;
      var groupEnabled = true;
      var callbackEnabled = true;
      late StateSetter rebuild;
      final focusChanges = <bool>[];

      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedToggleGroup<String>(
              selectedValue: 'a',
              enabled: groupEnabled,
              onChanged: callbackEnabled ? (_) {} : null,
              child: Row(
                children: [
                  const NakedToggleOption<String>(value: 'a', child: Text('A')),
                  NakedToggleOption<String>(
                    value: 'b',
                    enabled: optionEnabled,
                    focusNode: optionFocus,
                    onFocusChange: (value) {
                      focusChanges.add(value);
                      if (!value) rebuild(() {});
                    },
                    child: const Text('B'),
                  ),
                ],
              ),
            );
          },
        ),
      );

      Future<void> focusThenDisable(
        VoidCallback disable, {
        required int expectedPairs,
      }) async {
        optionFocus.requestFocus();
        await tester.pump();
        expect(optionFocus.hasPrimaryFocus, isTrue);

        rebuild(disable);
        await tester.pump();
        final expectedChanges = <bool>[
          for (var i = 0; i < expectedPairs; i++) ...[true, false],
        ];
        expect(focusChanges, expectedChanges);
        await tester.pump();
        expect(
          focusChanges,
          expectedChanges,
          reason: 'false is not duplicated',
        );
      }

      await focusThenDisable(() => optionEnabled = false, expectedPairs: 1);
      rebuild(() => optionEnabled = true);
      await tester.pump();

      await focusThenDisable(() => groupEnabled = false, expectedPairs: 2);
      rebuild(() => groupEnabled = true);
      await tester.pump();

      await focusThenDisable(() => callbackEnabled = false, expectedPairs: 3);
    });

    testStateScopeBuilder<NakedToggleState>(
      'builder\'s context contains NakedStateScope',
      (builder) =>
          NakedToggle(builder: builder, value: false, child: const SizedBox()),
    );

    group('asSwitch parameter', () {
      testWidgets('behaves as toggle button by default', (tester) async {
        bool value = false;
        await tester.pumpMaterialWidget(
          StatefulBuilder(
            builder: (context, setState) => NakedToggle(
              value: value,
              onChanged: (v) => setState(() => value = v),
              child: const Text('Toggle'),
            ),
          ),
        );

        await tester.tap(find.text('Toggle'));
        await tester.pump();
        expect(value, isTrue);
      });

      testWidgets('behaves as switch when asSwitch=true', (tester) async {
        bool value = false;
        await tester.pumpMaterialWidget(
          StatefulBuilder(
            builder: (context, setState) => NakedToggle(
              value: value,
              asSwitch: true,
              onChanged: (v) => setState(() => value = v),
              child: const Text('Switch'),
            ),
          ),
        );

        await tester.tap(find.text('Switch'));
        await tester.pump();
        expect(value, isTrue);
      });
    });
  });
}
