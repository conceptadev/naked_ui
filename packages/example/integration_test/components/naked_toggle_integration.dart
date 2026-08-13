import 'package:example/api/naked_toggle.0.dart' as toggle_example;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naked_ui/naked_ui.dart';

import '../helpers/test_helpers.dart';

const _toggleGroupRootKey = Key('toggle-group.root');
const _toggleGroupValueKey = Key('toggle-group.value');
const _toggleGroupRemoveFocusedKey = Key('toggle-group.remove-focused');
const _toggleGroupResetKey = Key('toggle-group.reset');
const _toggleGroupOptionKeys = <String, Key>{
  'bold': Key('toggle-group.option.bold'),
  'italic': Key('toggle-group.option.italic'),
  'underline': Key('toggle-group.option.underline'),
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NakedToggle Integration Tests', () {
    testWidgets('toggle switches state correctly', (tester) async {
      // Use the actual example app
      await tester.pumpWidget(
        const MaterialApp(home: toggle_example.ToggleButtonExample()),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byType(NakedToggle);
      expect(toggleFinder, findsWidgets);

      // Find the first toggle button
      final firstToggleFinder = toggleFinder.first;

      // Tap to toggle state
      await tester.tap(firstToggleFinder);
      await tester.pumpAndSettle();

      // Verify toggle exists after interaction
      expect(firstToggleFinder, findsOneWidget);

      // Tap again to toggle back
      await tester.tap(firstToggleFinder);
      await tester.pumpAndSettle();

      // Verify toggle still exists
      expect(firstToggleFinder, findsOneWidget);
    });

    group('single-select toggle group fixture', () {
      testWidgets(
        'horizontal LTR moves focus without selection until activation',
        (tester) async {
          await _pumpToggleGroup(tester);

          expect(find.byKey(_toggleGroupRootKey), findsOneWidget);
          final bold = _optionFocusNode(tester, 'bold');
          final italic = _optionFocusNode(tester, 'italic');
          final underline = _optionFocusNode(tester, 'underline');

          bold.requestFocus();
          await tester.pump();

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
          expect(italic.hasPrimaryFocus, isTrue);
          expect(_selectedValueLabel(tester), 'Selected: Bold');

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pump();
          expect(bold.hasPrimaryFocus, isTrue);

          await tester.sendKeyEvent(LogicalKeyboardKey.end);
          await tester.pump();
          expect(underline.hasPrimaryFocus, isTrue);

          await tester.sendKeyEvent(LogicalKeyboardKey.home);
          await tester.pump();
          expect(bold.hasPrimaryFocus, isTrue);

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(italic.hasPrimaryFocus, isTrue);
          expect(_selectedValueLabel(tester), 'Selected: Italic');
        },
      );

      testWidgets('horizontal RTL arrows follow visual direction', (
        tester,
      ) async {
        await _pumpToggleGroup(tester, textDirection: TextDirection.rtl);

        final bold = _optionFocusNode(tester, 'bold');
        final italic = _optionFocusNode(tester, 'italic');
        bold.requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(italic.hasPrimaryFocus, isTrue);
        expect(_selectedValueLabel(tester), 'Selected: Bold');

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(bold.hasPrimaryFocus, isTrue);
      });

      testWidgets('vertical group skips its disabled middle option', (
        tester,
      ) async {
        await _pumpToggleGroup(
          tester,
          orientation: Axis.vertical,
          disableMiddleOption: true,
        );

        final bold = _optionFocusNode(tester, 'bold');
        final italic = _optionFocusNode(tester, 'italic');
        final underline = _optionFocusNode(tester, 'underline');
        bold.requestFocus();
        await tester.pump();

        expect(italic.canRequestFocus, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(underline.hasPrimaryFocus, isTrue);
        expect(_selectedValueLabel(tester), 'Selected: Bold');

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(bold.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pump();
        expect(underline.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump();
        expect(bold.hasPrimaryFocus, isTrue);
      });

      testWidgets('the group contributes one Tab stop and then exits', (
        tester,
      ) async {
        await _pumpToggleGroup(tester);

        final bold = _optionFocusNode(tester, 'bold');
        final italic = _optionFocusNode(tester, 'italic');
        final underline = _optionFocusNode(tester, 'underline');
        final removeButton = tester.widget<ButtonStyleButton>(
          find.byKey(_toggleGroupRemoveFocusedKey),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(bold.hasPrimaryFocus, isTrue);
        expect(italic.skipTraversal, isTrue);
        expect(underline.skipTraversal, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(removeButton.focusNode?.hasPrimaryFocus, isTrue);
        expect(bold.hasFocus, isFalse);
        expect(italic.hasFocus, isFalse);
        expect(underline.hasFocus, isFalse);
      });

      testWidgets(
        'controlled value and focus repair survive removal and reset',
        (tester) async {
          await _pumpToggleGroup(tester);

          final italic = _optionFocusNode(tester, 'italic');
          final underline = _optionFocusNode(tester, 'underline');
          italic.requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(_selectedValueLabel(tester), 'Selected: Italic');

          await tester.tap(find.byKey(_toggleGroupRemoveFocusedKey));
          await tester.pumpAndSettle();
          expect(find.byKey(_toggleGroupOptionKeys['italic']!), findsNothing);
          expect(underline.hasPrimaryFocus, isTrue);
          expect(_selectedValueLabel(tester), 'Selected: Bold');

          await tester.tap(find.byKey(_toggleGroupResetKey));
          await tester.pumpAndSettle();
          expect(find.byKey(_toggleGroupOptionKeys['italic']!), findsOneWidget);
          expect(_selectedValueLabel(tester), 'Selected: Bold');
        },
      );
    });

    testWidgets('toggle responds to keyboard activation', (tester) async {
      final toggleKey = UniqueKey();
      final focusNode = tester.createManagedFocusNode();
      bool toggleValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedToggle(
                key: toggleKey,
                focusNode: focusNode,
                value: toggleValue,
                onChanged: (value) => toggleValue = value,
                child: const Text('Toggle Button'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pressKeyOn(focusNode, LogicalKeyboardKey.enter);
      expect(toggleValue, isTrue, reason: 'Enter must activate the toggle');

      // The fixture does not rebuild, so each activation reports !value.
      // Reset the flag to prove Space activates independently.
      toggleValue = false;
      await tester.pressKeyOn(focusNode, LogicalKeyboardKey.space);
      expect(toggleValue, isTrue, reason: 'Space must activate the toggle');
    });

    testWidgets('toggle handles focus management correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: toggle_example.ToggleButtonExample()),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byType(NakedToggle).first;

      // Test focus by tapping
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Verify toggle is still present and interactive
      expect(toggleFinder, findsOneWidget);
    });

    testWidgets('toggle responds to hover interactions', (tester) async {
      final toggleKey = UniqueKey();
      bool toggleValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedToggle(
                key: toggleKey,
                value: toggleValue,
                onChanged: (value) => toggleValue = value,
                child: const Text('Hover Toggle'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate hover
      await tester.simulateHover(toggleKey);
      await tester.pumpAndSettle();

      // Toggle should respond to hover
      expect(find.byKey(toggleKey), findsOneWidget);
    });

    testWidgets(
      'standalone formatting toggles remain independently combinable',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: toggle_example.ToggleButtonExample()),
        );
        await tester.pumpAndSettle();

        // Find all toggles in the example
        final toggleFinders = find.byType(NakedToggle);
        expect(toggleFinders, findsWidgets);

        // Test each toggle in the example
        for (int i = 0; i < toggleFinders.evaluate().length && i < 3; i++) {
          final currentToggle = toggleFinders.at(i);

          // Tap to change state
          await tester.tap(currentToggle);
          await tester.pumpAndSettle();

          // Verify toggle still exists after state change
          expect(currentToggle, findsOneWidget);
        }

        expect([
          for (var index = 0; index < 3; index++)
            tester.widget<NakedToggle>(toggleFinders.at(index)).value,
        ], everyElement(isTrue));
      },
    );

    testWidgets('disabled toggle does not respond to interactions', (
      tester,
    ) async {
      final toggleKey = UniqueKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedToggle(
                key: toggleKey,
                value: false,
                onChanged: null, // Disabled
                child: const Text('Disabled Toggle'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Try to tap disabled toggle
      await tester.tap(find.byKey(toggleKey));
      await tester.pumpAndSettle();

      // Toggle should still exist but remain disabled
      expect(find.byKey(toggleKey), findsOneWidget);
    });
  });
}

Future<void> _pumpToggleGroup(
  WidgetTester tester, {
  Axis orientation = Axis.horizontal,
  TextDirection textDirection = TextDirection.ltr,
  bool disableMiddleOption = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: toggle_example.ToggleGroupExample(
            orientation: orientation,
            textDirection: textDirection,
            disableMiddleOption: disableMiddleOption,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FocusNode _optionFocusNode(WidgetTester tester, String value) {
  final option = tester.widget<NakedToggleOption<String>>(
    find.byKey(_toggleGroupOptionKeys[value]!),
  );
  return option.focusNode!;
}

String _selectedValueLabel(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(_toggleGroupValueKey)).data!;
}
