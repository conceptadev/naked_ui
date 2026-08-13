import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naked_ui/naked_ui.dart';
import 'package:example/api/naked_slider.0.dart' as slider_example;

import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NakedSlider Integration Tests', () {
    testWidgets('slider value changes via drag', (tester) async {
      // Use the actual example app
      await tester.pumpWidget(const slider_example.MyApp());
      await tester.pump(const Duration(milliseconds: 100));

      final sliderFinder = find.byType(NakedSlider);
      expect(sliderFinder, findsOneWidget);

      // Initial value should be 0.5
      tester.expectSliderValue(sliderFinder, 0.5);

      // Drag to change value
      await tester.dragSlider(sliderFinder, 0.8);

      // Value should be updated (approximately)
      tester.expectSliderValue(sliderFinder, 0.8, tolerance: 0.1);
    });

    testWidgets('slider responds to keyboard navigation', (tester) async {
      final sliderKey = UniqueKey();
      final focusNode = tester.createManagedFocusNode();
      double currentValue = 0.5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedSlider(
                key: sliderKey,
                values: [currentValue],
                min: 0,
                max: 1,
                step: 0.01,
                focusNodes: [focusNode],
                onChanged: (values) => currentValue = values.single,
                child: Container(
                  width: 200,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the slider
      focusNode.requestFocus();
      await tester.pump();

      // Test right arrow (increment)
      await tester.sendArrowKey(LogicalKeyboardKey.arrowRight);
      expect(currentValue, greaterThan(0.5));

      // Test left arrow (decrement)
      double valueBeforeLeft = currentValue;
      await tester.sendArrowKey(LogicalKeyboardKey.arrowLeft);
      expect(currentValue, lessThan(valueBeforeLeft));

      // Test Home key (minimum)
      await tester.sendHomeEndKey(LogicalKeyboardKey.home);
      expect(currentValue, equals(0.0));

      // Test End key (maximum)
      await tester.sendHomeEndKey(LogicalKeyboardKey.end);
      expect(currentValue, equals(1.0));
    });

    testWidgets('slider callbacks work correctly', (tester) async {
      final sliderKey = UniqueKey();
      double currentValue = 0.5;
      bool dragStarted = false;
      bool dragEnded = false;
      bool valueChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedSlider(
                key: sliderKey,
                values: [currentValue],
                min: 0,
                max: 1,
                step: 0.01,
                onChanged: (values) {
                  currentValue = values.single;
                  valueChanged = true;
                },
                onChangeStart: (values) {
                  dragStarted = true;
                },
                onChangeEnd: (values) {
                  dragEnded = true;
                },
                child: Container(
                  width: 200,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Perform drag gesture
      final center = tester.getCenter(find.byKey(sliderKey));
      final gesture = await tester.startGesture(center);
      await tester.pump();

      // Check drag start callback
      expect(dragStarted, isTrue);

      // Move and check value change
      await gesture.moveTo(center + const Offset(50, 0));
      await tester.pump();
      expect(valueChanged, isTrue);

      // End drag and check callback
      await gesture.up();
      await tester.pump();
      expect(dragEnded, isTrue);
    });

    testWidgets('slider state callbacks work correctly', (tester) async {
      final sliderKey = UniqueKey();
      final focusNode = tester.createManagedFocusNode();
      bool isHovered = false;
      bool isFocused = false;
      double currentValue = 0.5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedSlider(
                key: sliderKey,
                values: [currentValue],
                min: 0,
                max: 1,
                step: 0.01,
                focusNodes: [focusNode],
                onChanged: (values) => currentValue = values.single,
                onHoverChange: (hovered) => isHovered = hovered,
                onFocusChange: (focused) => isFocused = focused,
                child: Container(
                  width: 200,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test hover state
      await tester.simulateHover(sliderKey, until: () => isHovered);

      // Test focus state
      focusNode.requestFocus();
      await tester.pump();
      expect(isFocused, isTrue);
    });

    testWidgets('disabled slider blocks interactions', (tester) async {
      final sliderKey = UniqueKey();
      double currentValue = 0.5;
      bool valueChanged = false;
      bool hoverChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedSlider(
                key: sliderKey,
                values: [currentValue],
                min: 0,
                max: 1,
                step: 0.01,
                enabled: false,
                onChanged: (values) => valueChanged = true,
                onHoverChange: (hovered) => hoverChanged = true,
                child: Container(
                  width: 200,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Try to drag - should not work
      await tester.dragSlider(find.byKey(sliderKey), 0.8);
      expect(valueChanged, isFalse);

      // Test hover doesn't trigger callback when disabled
      await tester.simulateHover(sliderKey);
      expect(hoverChanged, isFalse);
    });

    testWidgets('slider respects min/max bounds', (tester) async {
      final sliderKey = UniqueKey();
      double currentValue = 10.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedSlider(
                key: sliderKey,
                values: [currentValue],
                min: 5.0,
                max: 15.0,
                onChanged: (values) => currentValue = values.single,
                child: Container(
                  width: 200,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag far to the left (should clamp to min)
      final center = tester.getCenter(find.byKey(sliderKey));
      final gesture = await tester.startGesture(center);
      await gesture.moveTo(center + const Offset(-200, 0)); // Far left
      await gesture.up();
      await tester.pump();

      expect(currentValue, greaterThanOrEqualTo(5.0));

      // Drag far to the right (should clamp to max)
      final gesture2 = await tester.startGesture(center);
      await gesture2.moveTo(center + const Offset(200, 0)); // Far right
      await gesture2.up();
      await tester.pump();

      expect(currentValue, lessThanOrEqualTo(15.0));
    });

    testWidgets('slider works with divisions for discrete values', (
      tester,
    ) async {
      final sliderKey = UniqueKey();
      double currentValue = 0.5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NakedSlider(
                key: sliderKey,
                values: [currentValue],
                min: 0.0,
                max: 1.0,
                step: 0.25,
                onChanged: (values) => currentValue = values.single,
                child: Container(
                  width: 200,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag to approximately 0.3 - should snap to 0.25
      await tester.dragSlider(find.byKey(sliderKey), 0.3);

      // Value should be snapped to nearest division
      expect([0.0, 0.25, 0.5, 0.75, 1.0].contains(currentValue), isTrue);
    });

    testWidgets('works with example app styling', (tester) async {
      // Test the full example with custom painting
      await tester.pumpWidget(const slider_example.MyApp());
      await tester.pump(const Duration(milliseconds: 100));

      final sliderFinder = find.byType(NakedSlider);
      expect(sliderFinder, findsOneWidget);

      // Find the custom painted elements
      final customPaintFinder = find.descendant(
        of: sliderFinder,
        matching: find.byType(CustomPaint),
      );
      expect(
        customPaintFinder,
        findsOneWidget,
      ); // Single CustomPaint with both track and thumb painters

      // Test interaction with styled slider
      await tester.dragSlider(sliderFinder, 0.2);
      tester.expectSliderValue(sliderFinder, 0.2, tolerance: 0.1);

      // Test another drag
      await tester.dragSlider(sliderFinder, 0.9);
      tester.expectSliderValue(sliderFinder, 0.9, tolerance: 0.1);
    });
  });
}
