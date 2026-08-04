import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'semantics_test_utils.dart';

void main() {
  Widget _buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  Widget _buildMaterialSwitch({required bool value, required bool enabled}) {
    return Switch(value: value, onChanged: enabled ? (_) {} : null);
  }

  Widget _buildNakedToggleAsSwitch({
    required bool value,
    required bool enabled,
  }) {
    return NakedToggle(
      value: value,
      onChanged: enabled ? (_) {} : null,
      asSwitch: true,
      child: const SizedBox(
        width: 40,
        height: 20,
      ), // No text to match Material Switch
    );
  }

  Widget _buildNakedToggleAsButton({
    required bool value,
    required bool enabled,
  }) {
    return NakedToggle(
      value: value,
      onChanged: enabled ? (_) {} : null,
      asSwitch: false, // Button semantics
      child: const Text('Toggle'),
    );
  }

  group('NakedToggle Semantics', () {
    group('Switch-like semantics (asSwitch: true)', () {
      testWidgets('parity with Material Switch when off', (tester) async {
        final handle = tester.ensureSemantics();
        await expectSemanticsParity(
          tester: tester,
          material: _buildTestApp(
            _buildMaterialSwitch(value: false, enabled: true),
          ),
          naked: _buildTestApp(
            _buildNakedToggleAsSwitch(value: false, enabled: true),
          ),
          control: ControlType.toggle,
        );
        handle.dispose();
      });

      testWidgets('parity with Material Switch when on', (tester) async {
        final handle = tester.ensureSemantics();
        await expectSemanticsParity(
          tester: tester,
          material: _buildTestApp(
            _buildMaterialSwitch(value: true, enabled: true),
          ),
          naked: _buildTestApp(
            _buildNakedToggleAsSwitch(value: true, enabled: true),
          ),
          control: ControlType.toggle,
        );
        handle.dispose();
      });

      testWidgets('parity with Material Switch when disabled', (tester) async {
        final handle = tester.ensureSemantics();
        await expectSemanticsParity(
          tester: tester,
          material: _buildTestApp(
            _buildMaterialSwitch(value: false, enabled: false),
          ),
          naked: _buildTestApp(
            _buildNakedToggleAsSwitch(value: false, enabled: false),
          ),
          control: ControlType.toggle,
        );
        handle.dispose();
      });
    });

    group('Button-like semantics (asSwitch: false)', () {
      testWidgets('button toggle semantics when off', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _buildTestApp(_buildNakedToggleAsButton(value: false, enabled: true)),
        );

        final summary = summarizeMergedFromRoot(
          tester,
          control: ControlType.button,
        );

        // Verify it has button semantics with toggle state
        expect(summary.flags.contains('isButton'), isTrue);
        expect(summary.flags.contains('hasToggledState'), isTrue);
        expect(summary.flags.contains('isToggled'), isFalse);
        expect(summary.actions.contains('tap'), isTrue);

        handle.dispose();
      });

      testWidgets('button toggle semantics when on', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _buildTestApp(_buildNakedToggleAsButton(value: true, enabled: true)),
        );

        final summary = summarizeMergedFromRoot(
          tester,
          control: ControlType.button,
        );

        // Verify it has button semantics with toggle state
        expect(summary.flags.contains('isButton'), isTrue);
        expect(summary.flags.contains('hasToggledState'), isTrue);
        expect(summary.flags.contains('isToggled'), isTrue);
        expect(summary.actions.contains('tap'), isTrue);

        handle.dispose();
      });
    });

    group('Focus and hover states', () {
      testWidgets('switch focus parity', (tester) async {
        final handle = tester.ensureSemantics();
        final focusNodeMaterial = FocusNode();
        final focusNodeNaked = FocusNode();

        // Material focused
        await tester.pumpWidget(
          _buildTestApp(
            Switch(
              value: false,
              onChanged: (_) {},
              focusNode: focusNodeMaterial,
            ),
          ),
        );
        focusNodeMaterial.requestFocus();
        await tester.pump();
        final materialFocused = summarizeMergedFromRoot(
          tester,
          control: ControlType.toggle,
        );

        // Naked focused
        await tester.pumpWidget(
          _buildTestApp(
            NakedToggle(
              value: false,
              onChanged: (_) {},
              asSwitch: true,
              focusNode: focusNodeNaked,
              child: const SizedBox(
                width: 40,
                height: 20,
              ), // No text to match Material Switch
            ),
          ),
        );
        focusNodeNaked.requestFocus();
        await tester.pump();
        final nakedFocused = summarizeMergedFromRoot(
          tester,
          control: ControlType.toggle,
        );

        expect(nakedFocused, equals(materialFocused));

        focusNodeMaterial.dispose();
        focusNodeNaked.dispose();
        handle.dispose();
      });

      testWidgets('switch hover parity', (tester) async {
        final handle = tester.ensureSemantics();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await tester.pump();

        // Material hovered
        await tester.pumpWidget(
          _buildTestApp(_buildMaterialSwitch(value: false, enabled: true)),
        );
        await mouse.moveTo(tester.getCenter(find.byType(Switch)));
        await tester.pump();
        final materialHovered = summarizeMergedFromRoot(
          tester,
          control: ControlType.toggle,
        );

        // Naked hovered
        await tester.pumpWidget(
          _buildTestApp(_buildNakedToggleAsSwitch(value: false, enabled: true)),
        );
        await mouse.moveTo(tester.getCenter(find.byType(NakedToggle)));
        await tester.pump();
        final nakedHovered = summarizeMergedFromRoot(
          tester,
          control: ControlType.toggle,
        );

        expect(nakedHovered, equals(materialHovered));

        await mouse.removePointer();
        handle.dispose();
      });
    });

    group('NakedToggleGroup semantics', () {
      testWidgets('toggle group basic functionality', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _buildTestApp(
            NakedToggleGroup<String>(
              selectedValue: 'option1',
              onChanged: (_) {},
              child: Column(
                children: [
                  NakedToggleOption<String>(
                    value: 'option1',
                    child: const Text('Option 1'),
                  ),
                  NakedToggleOption<String>(
                    value: 'option2',
                    child: const Text('Option 2'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Verify toggle group renders correctly
        expect(find.text('Option 1'), findsOneWidget);
        expect(find.text('Option 2'), findsOneWidget);

        handle.dispose();
      });

      testWidgets('uses one group label and button plus selected options', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _buildTestApp(
            NakedToggleGroup<String>(
              selectedValue: 'bold',
              onChanged: (_) {},
              semanticLabel: 'Formatting',
              child: Row(
                children: const [
                  NakedToggleOption<String>(
                    value: 'bold',
                    semanticLabel: 'Bold',
                    child: SizedBox(width: 20, height: 20),
                  ),
                  NakedToggleOption<String>(
                    value: 'italic',
                    semanticLabel: 'Italic',
                    child: SizedBox(width: 20, height: 20),
                  ),
                ],
              ),
            ),
          ),
        );

        final root = tester.getSemantics(find.byType(Scaffold));
        final groupNodes = collectSemanticsNodes(
          root,
          (node) => node.getSemanticsData().label == 'Formatting',
        );
        expect(groupNodes, hasLength(1));

        final optionNodes = collectSemanticsNodes(
          groupNodes.single,
          (node) => node.getSemanticsData().flagsCollection.isButton,
        );
        expect(optionNodes, hasLength(2));

        final bold = optionNodes.singleWhere(
          (node) => node.getSemanticsData().label == 'Bold',
        );
        final italic = optionNodes.singleWhere(
          (node) => node.getSemanticsData().label == 'Italic',
        );
        expect(
          bold.getSemanticsData().flagsCollection.isSelected,
          Tristate.isTrue,
        );
        expect(
          italic.getSemanticsData().flagsCollection.isSelected,
          Tristate.isFalse,
        );
        for (final option in optionNodes) {
          final summary = summarizeNode(option);
          expect(summary.flags, isNot(contains('hasToggledState')));
          expect(summary.flags, isNot(contains('hasCheckedState')));
          expect(summary.flags, contains('isInMutuallyExclusiveGroup'));
        }

        handle.dispose();
      });

      testWidgets('disabled options have no tap action', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _buildTestApp(
            NakedToggleGroup<String>(
              selectedValue: 'bold',
              onChanged: (_) {},
              child: Row(
                children: const [
                  NakedToggleOption<String>(
                    value: 'bold',
                    semanticLabel: 'Bold',
                    child: SizedBox(width: 20, height: 20),
                  ),
                  NakedToggleOption<String>(
                    value: 'italic',
                    enabled: false,
                    semanticLabel: 'Italic',
                    child: SizedBox(width: 20, height: 20),
                  ),
                ],
              ),
            ),
          ),
        );

        final root = tester.getSemantics(find.byType(Scaffold));
        final italic = findSemanticsNode(
          root,
          (node) => node.getSemanticsData().label == 'Italic',
        )!;
        final data = italic.getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(data.flagsCollection.isEnabled, Tristate.isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);

        handle.dispose();
      });

      testWidgets(
        'semantic taps emit once and selected activation is a no-op',
        (tester) async {
          final handle = tester.ensureSemantics();
          final proposedValues = <String?>[];

          await tester.pumpWidget(
            _buildTestApp(
              NakedToggleGroup<String>(
                selectedValue: 'bold',
                onChanged: proposedValues.add,
                child: Row(
                  children: const [
                    NakedToggleOption<String>(
                      value: 'bold',
                      semanticLabel: 'Bold',
                      child: SizedBox(width: 20, height: 20),
                    ),
                    NakedToggleOption<String>(
                      value: 'italic',
                      semanticLabel: 'Italic',
                      child: SizedBox(width: 20, height: 20),
                    ),
                  ],
                ),
              ),
            ),
          );

          final root = tester.getSemantics(find.byType(Scaffold));
          final bold = findSemanticsNode(
            root,
            (node) => node.getSemanticsData().label == 'Bold',
          )!;
          final italic = findSemanticsNode(
            root,
            (node) => node.getSemanticsData().label == 'Italic',
          )!;

          italic.owner!.performAction(italic.id, SemanticsAction.tap);
          await tester.pump();
          expect(proposedValues, ['italic']);

          bold.owner!.performAction(bold.id, SemanticsAction.tap);
          await tester.pump();
          expect(proposedValues, ['italic']);

          handle.dispose();
        },
      );

      testWidgets('excludeSemantics hides the group and all options', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _buildTestApp(
            NakedToggleGroup<String>(
              selectedValue: 'bold',
              onChanged: (_) {},
              semanticLabel: 'Formatting',
              excludeSemantics: true,
              child: const NakedToggleOption<String>(
                value: 'bold',
                semanticLabel: 'Bold',
                child: SizedBox(width: 20, height: 20),
              ),
            ),
          ),
        );

        final root = tester.getSemantics(find.byType(Scaffold));
        expect(
          collectSemanticsNodes(
            root,
            (node) => node.getSemanticsData().flagsCollection.isButton,
          ),
          isEmpty,
        );
        expect(
          collectSemanticsNodes(
            root,
            (node) => const {
              'Formatting',
              'Bold',
            }.contains(node.getSemanticsData().label),
          ),
          isEmpty,
        );

        handle.dispose();
      });
    });

    testWidgets('toggle with semantic label', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedToggle(
            value: false,
            onChanged: (_) {},
            semanticLabel: 'Enable notifications',
            asSwitch: true,
            child: const Text('Notifications'),
          ),
        ),
      );

      final summary = summarizeMergedFromRoot(
        tester,
        control: ControlType.toggle,
      );
      expect(summary.label, equals('Enable notifications'));

      handle.dispose();
    });
  });
}
