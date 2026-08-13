import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

extension SliderTestHelpers on WidgetTester {
  /// Simulate drag gesture to change slider value
  Future<void> dragSlider(Finder finder, double targetValue) async {
    final slider = widget<NakedSlider>(finder);
    final box = getSize(finder);
    final center = getCenter(finder);
    final rect = getRect(finder);

    // Calculate current position based on current value
    final currentNormalizedValue =
        (slider.values.first - slider.min) / (slider.max - slider.min);
    final currentOffset = Offset(
      rect.left + (box.width * currentNormalizedValue),
      center.dy,
    );

    // Calculate target position based on target value
    final normalizedValue =
        (targetValue - slider.min) / (slider.max - slider.min);
    final targetOffset = Offset(
      rect.left + (box.width * normalizedValue),
      center.dy,
    );

    // Start drag from current value position to target
    final gesture = await startGesture(currentOffset);
    await pump();
    await gesture.moveTo(targetOffset);
    await pump();
    await gesture.up();
    await pump();
  }

  /// Verify slider value matches expected value
  void expectSliderValue(
    Finder finder,
    double expected, {
    double tolerance = 0.01,
  }) {
    final slider = widget<NakedSlider>(finder);
    expect(slider.values.first, closeTo(expected, tolerance));
  }

  /// Send keyboard arrow keys to slider as a full press (down+up).
  /// Using sendKeyEvent keeps the pressed-set consistent in Live bindings.
  Future<void> sendArrowKey(LogicalKeyboardKey key) async {
    await sendKeyEvent(key);
    await pump();
  }

  /// Send Home/End keys to slider as a full press (down+up).
  Future<void> sendHomeEndKey(LogicalKeyboardKey key) async {
    await sendKeyEvent(key);
    await pump();
  }
}
