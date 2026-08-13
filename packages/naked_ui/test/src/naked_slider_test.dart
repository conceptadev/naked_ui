import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

void main() {
  const sliderKey = Key('slider');

  Widget harness({
    required List<double> values,
    ValueChanged<List<double>>? onChanged,
    ValueChanged<List<double>>? onChangeStart,
    ValueChanged<List<double>>? onChangeEnd,
    ValueChanged<bool>? onDragChange,
    ValueChanged<bool>? onHoverChange,
    ValueChanged<bool>? onFocusChange,
    double min = 0,
    double max = 100,
    double step = 1,
    double minSpacing = 0,
    Axis orientation = Axis.horizontal,
    bool inverted = false,
    bool enabled = true,
    bool acceptChanges = true,
    TextDirection textDirection = TextDirection.ltr,
    List<FocusNode?>? focusNodes,
    int? autofocusThumbIndex,
    Size size = const Size(200, 48),
    ValueChanged<NakedSliderState>? onBuild,
  }) {
    var currentValues = List<double>.of(values);

    return MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Center(
          child: SizedBox.fromSize(
            size: size,
            child: StatefulBuilder(
              builder: (context, setState) => NakedSlider(
                key: sliderKey,
                values: currentValues,
                min: min,
                max: max,
                step: step,
                minSpacing: minSpacing,
                orientation: orientation,
                inverted: inverted,
                enabled: enabled,
                focusNodes: focusNodes,
                autofocusThumbIndex: autofocusThumbIndex,
                onChanged: onChanged == null
                    ? null
                    : (next) {
                        onChanged(next);
                        if (acceptChanges) {
                          setState(() => currentValues = List<double>.of(next));
                        }
                      },
                onChangeStart: onChangeStart,
                onChangeEnd: onChangeEnd,
                onDragChange: onDragChange,
                onHoverChange: onHoverChange,
                onFocusChange: onFocusChange,
                builder: (context, state, child) {
                  onBuild?.call(state);

                  return const ColoredBox(color: Colors.blue);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset pointAt(WidgetTester tester, double percentage) {
    final rect = tester.getRect(find.byKey(sliderKey));

    return Offset(rect.left + rect.width * percentage, rect.center.dy);
  }

  Offset verticalPointAt(WidgetTester tester, double percentageFromTop) {
    final rect = tester.getRect(find.byKey(sliderKey));

    return Offset(rect.center.dx, rect.top + rect.height * percentageFromTop);
  }

  group('contract', () {
    test('defaults match the Radix-shaped contract', () {
      final slider = NakedSlider(
        values: const [25],
        onChanged: (_) {},
        child: const SizedBox(),
      );

      expect(slider.min, 0);
      expect(slider.max, 100);
      expect(slider.step, 1);
      expect(slider.minSpacing, 0);
      expect(slider.orientation, Axis.horizontal);
      expect(slider.inverted, isFalse);
    });

    test('rejects empty and invalid value lists', () {
      expect(
        () => NakedSlider(values: const [], child: const SizedBox()),
        throwsAssertionError,
      );
      expect(
        () => NakedSlider(
          values: const [60, 40],
          child: const SizedBox(),
        ).createState(),
        throwsAssertionError,
      );
      expect(
        () => NakedSlider(
          values: const [20, 25],
          minSpacing: 10,
          child: const SizedBox(),
        ).createState(),
        throwsAssertionError,
      );
      expect(
        () => NakedSlider(
          values: const [-1],
          child: const SizedBox(),
        ).createState(),
        throwsAssertionError,
      );
    });

    test('rejects per-thumb lists with mismatched lengths', () {
      expect(
        () => NakedSlider(
          values: const [25, 75],
          focusNodes: const [null],
          child: const SizedBox(),
        ),
        throwsAssertionError,
      );
      expect(
        () => NakedSlider(
          values: const [25, 75],
          semanticLabels: const ['Minimum'],
          child: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });
  });

  group('state', () {
    testWidgets('builder receives an immutable arbitrary-thumb snapshot', (
      tester,
    ) async {
      NakedSliderState? state;
      await tester.pumpWidget(
        harness(
          values: const [10, 40, 90],
          onChanged: (_) {},
          onBuild: (value) => state = value,
        ),
      );

      expect(state!.values, [10, 40, 90]);
      expect(state!.percentages, [0.1, 0.4, 0.9]);
      expect(state!.visualPercentageAt(1), 0.4);
      expect(() => state!.values[0] = 0, throwsUnsupportedError);
    });

    testWidgets('builder context contains the slider state scope', (
      tester,
    ) async {
      NakedSliderState? scoped;
      await tester.pumpWidget(
        MaterialApp(
          home: NakedSlider(
            values: const [25, 75],
            onChanged: (_) {},
            builder: (context, state, child) {
              scoped = NakedSliderState.of(context);

              return const SizedBox(width: 200, height: 48);
            },
          ),
        ),
      );

      expect(scoped!.values, [25, 75]);
    });

    test('equality and hash code include list and interaction state', () {
      NakedSliderState create(List<double> values) => NakedSliderState(
        states: const {WidgetState.focused, WidgetState.hovered},
        values: values,
        min: 0,
        max: 100,
        step: 1,
        minSpacing: 0,
        orientation: Axis.horizontal,
        inverted: false,
        textDirection: TextDirection.ltr,
        isDragging: false,
      );

      final first = create([25, 75]);
      final equal = create([25, 75]);
      final different = create([25, 80]);
      expect(first, equal);
      expect(first.hashCode, equal.hashCode);
      expect(first, isNot(different));
    });

    test(
      'visualPercentageOf flips for direction, orientation, and inversion',
      () {
        NakedSliderState create({
          Axis orientation = Axis.horizontal,
          TextDirection textDirection = TextDirection.ltr,
          bool inverted = false,
        }) => NakedSliderState(
          states: const <WidgetState>{},
          values: const [50],
          min: 0,
          max: 100,
          step: 1,
          minSpacing: 0,
          orientation: orientation,
          inverted: inverted,
          textDirection: textDirection,
          isDragging: false,
        );

        // Left-to-right horizontal maps the logical fraction straight through.
        expect(create().visualPercentageOf(0), 0);
        expect(create().visualPercentageOf(0.25), 0.25);
        expect(create().visualPercentageOf(1), 1);

        // Each of RTL, vertical, and inversion mirrors the fraction once.
        expect(
          create(textDirection: TextDirection.rtl).visualPercentageOf(0.25),
          0.75,
        );
        expect(
          create(orientation: Axis.vertical).visualPercentageOf(0.25),
          0.75,
        );
        expect(create(inverted: true).visualPercentageOf(0.25), 0.75);

        // Two mirrors cancel out (RTL combined with inversion).
        expect(
          create(
            textDirection: TextDirection.rtl,
            inverted: true,
          ).visualPercentageOf(0.25),
          0.25,
        );

        // visualPercentageAt stays consistent with the delegated helper.
        final state = create(inverted: true);
        expect(
          state.visualPercentageAt(0),
          state.visualPercentageOf(state.percentageAt(0)),
        );
      },
    );
  });

  group('pointer behavior', () {
    testWidgets('a single drag move updates the active thumb', (tester) async {
      final changes = <List<double>>[];
      await tester.pumpWidget(
        harness(values: const [50], onChanged: changes.add),
      );

      final gesture = await tester.startGesture(pointAt(tester, 0.5));
      await gesture.moveTo(pointAt(tester, 0.8));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(changes.last, [80]);
    });

    testWidgets('tap selects and changes the nearest thumb', (tester) async {
      final changes = <List<double>>[];
      await tester.pumpWidget(
        harness(values: const [20, 80], onChanged: changes.add),
      );

      await tester.tapAt(pointAt(tester, 0.3));
      await tester.pump();
      expect(changes.last, [30, 80]);

      await tester.tapAt(pointAt(tester, 0.7));
      await tester.pump();
      expect(changes.last, [30, 70]);
    });

    testWidgets('supports three or more thumbs', (tester) async {
      final changes = <List<double>>[];
      await tester.pumpWidget(
        harness(values: const [10, 50, 90], onChanged: changes.add),
      );

      await tester.tapAt(pointAt(tester, 0.6));
      await tester.pump();

      expect(changes.last, [10, 60, 90]);
    });

    testWidgets('thumbs do not cross and honor minimum spacing', (
      tester,
    ) async {
      final changes = <List<double>>[];
      await tester.pumpWidget(
        harness(values: const [20, 80], minSpacing: 10, onChanged: changes.add),
      );

      final gesture = await tester.startGesture(pointAt(tester, 0.2));
      await gesture.moveTo(pointAt(tester, 0.3));
      await tester.pump();
      await gesture.moveTo(pointAt(tester, 0.9));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(changes.last, [70, 80]);
    });

    testWidgets('pointer values snap to step', (tester) async {
      final changes = <List<double>>[];
      await tester.pumpWidget(
        harness(values: const [0], step: 10, onChanged: changes.add),
      );

      await tester.tapAt(pointAt(tester, 0.56));
      await tester.pump();

      expect(changes.last, [60]);
    });

    testWidgets('controlled rejection does not mutate visible state', (
      tester,
    ) async {
      final states = <NakedSliderState>[];
      await tester.pumpWidget(
        harness(
          values: const [20, 80],
          onChanged: (_) {},
          acceptChanges: false,
          onBuild: states.add,
        ),
      );

      await tester.tapAt(pointAt(tester, 0.3));
      await tester.pump();

      expect(states.last.values, [20, 80]);
    });

    testWidgets('drag lifecycle returns complete start and end lists', (
      tester,
    ) async {
      final starts = <List<double>>[];
      final ends = <List<double>>[];
      final dragStates = <bool>[];
      await tester.pumpWidget(
        harness(
          values: const [20, 80],
          onChanged: (_) {},
          onChangeStart: starts.add,
          onChangeEnd: ends.add,
          onDragChange: dragStates.add,
        ),
      );

      final gesture = await tester.startGesture(pointAt(tester, 0.2));
      await gesture.moveTo(pointAt(tester, 0.3));
      await tester.pump();
      await gesture.moveTo(pointAt(tester, 0.4));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(starts, [
        [20, 80],
      ]);
      expect(ends, [
        [40, 80],
      ]);
      expect(dragStates, [true, false]);
    });

    testWidgets('cancel ends an active interaction', (tester) async {
      final ends = <List<double>>[];
      final dragStates = <bool>[];
      await tester.pumpWidget(
        harness(
          values: const [20, 80],
          onChanged: (_) {},
          onChangeEnd: ends.add,
          onDragChange: dragStates.add,
        ),
      );

      final gesture = await tester.startGesture(pointAt(tester, 0.2));
      await gesture.moveTo(pointAt(tester, 0.3));
      await tester.pump();
      await gesture.moveTo(pointAt(tester, 0.4));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      expect(ends.single, [40, 80]);
      expect(dragStates, [true, false]);
    });

    testWidgets('RTL reverses horizontal value direction', (tester) async {
      final changes = <List<double>>[];
      await tester.pumpWidget(
        harness(
          values: const [50],
          textDirection: TextDirection.rtl,
          onChanged: changes.add,
        ),
      );

      await tester.tapAt(pointAt(tester, 0.25));
      await tester.pump();

      expect(changes.last, [75]);
    });

    testWidgets('inversion reverses horizontal value direction', (
      tester,
    ) async {
      final changes = <List<double>>[];
      await tester.pumpWidget(
        harness(values: const [50], inverted: true, onChanged: changes.add),
      );

      await tester.tapAt(pointAt(tester, 0.25));
      await tester.pump();

      expect(changes.last, [75]);
    });

    testWidgets('vertical values increase from bottom to top', (tester) async {
      final changes = <List<double>>[];
      await tester.pumpWidget(
        harness(
          values: const [50],
          orientation: Axis.vertical,
          size: const Size(48, 200),
          onChanged: changes.add,
        ),
      );

      await tester.tapAt(verticalPointAt(tester, 0.25));
      await tester.pump();
      expect(changes.last, [75]);
    });

    testWidgets('vertical inversion increases from top to bottom', (
      tester,
    ) async {
      final changes = <List<double>>[];
      await tester.pumpWidget(
        harness(
          values: const [50],
          orientation: Axis.vertical,
          inverted: true,
          size: const Size(48, 200),
          onChanged: changes.add,
        ),
      );

      await tester.tapAt(verticalPointAt(tester, 0.25));
      await tester.pump();
      expect(changes.last, [25]);
    });
  });

  group('keyboard and focus', () {
    testWidgets('each thumb has independent focus and keyboard control', (
      tester,
    ) async {
      final first = FocusNode();
      final second = FocusNode();
      final changes = <List<double>>[];
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(
        harness(
          values: const [20, 80],
          focusNodes: [first, second],
          onChanged: changes.add,
        ),
      );

      second.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(first.hasFocus, isFalse);
      expect(second.hasFocus, isTrue);
      expect(changes.last, [20, 79]);
    });

    testWidgets('keyboard changes cannot cross adjacent thumbs', (
      tester,
    ) async {
      final first = FocusNode();
      final changes = <List<double>>[];
      addTearDown(first.dispose);
      await tester.pumpWidget(
        harness(
          values: const [20, 30],
          minSpacing: 10,
          focusNodes: [first, null],
          onChanged: changes.add,
        ),
      );

      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(changes, isEmpty);
    });

    testWidgets('Home and End honor neighboring-thumb constraints', (
      tester,
    ) async {
      final second = FocusNode();
      final changes = <List<double>>[];
      addTearDown(second.dispose);
      await tester.pumpWidget(
        harness(
          values: const [20, 60, 90],
          minSpacing: 10,
          focusNodes: [null, second, null],
          onChanged: changes.add,
        ),
      );

      second.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(changes.last, [20, 30, 90]);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(changes.last, [20, 80, 90]);
    });

    testWidgets('RTL and inversion affect horizontal arrow direction', (
      tester,
    ) async {
      final focus = FocusNode();
      final changes = <List<double>>[];
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        harness(
          values: const [50],
          textDirection: TextDirection.rtl,
          inverted: true,
          focusNodes: [focus],
          onChanged: changes.add,
        ),
      );

      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(changes.last, [51]);
    });

    testWidgets('focus callback reflects aggregate thumb focus', (
      tester,
    ) async {
      final first = FocusNode();
      final second = FocusNode();
      final focusStates = <bool>[];
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(
        harness(
          values: const [20, 80],
          focusNodes: [first, second],
          onChanged: (_) {},
          onFocusChange: focusStates.add,
        ),
      );

      first.requestFocus();
      await tester.pump();
      second.requestFocus();
      await tester.pump();
      second.unfocus();
      await tester.pump();

      expect(focusStates, [true, false]);
    });

    testWidgets('disabled slider cannot be focused or changed', (tester) async {
      final focus = FocusNode();
      final changes = <List<double>>[];
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        harness(
          values: const [50],
          enabled: false,
          focusNodes: [focus],
          onChanged: changes.add,
        ),
      );

      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.tapAt(pointAt(tester, 0.75));
      await tester.pump();

      expect(focus.hasFocus, isFalse);
      expect(changes, isEmpty);
    });
  });

  group('interaction states', () {
    testWidgets('hover callback reflects enabled state', (tester) async {
      final hovers = <bool>[];
      await tester.pumpWidget(
        harness(
          values: const [50],
          onChanged: (_) {},
          onHoverChange: hovers.add,
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(find.byKey(sliderKey)));
      await tester.pump();
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await mouse.removePointer();

      expect(hovers, [true, false]);
    });

    testWidgets('builder identifies active and focused thumbs', (tester) async {
      final states = <NakedSliderState>[];
      await tester.pumpWidget(
        harness(values: const [20, 80], onChanged: (_) {}, onBuild: states.add),
      );

      final gesture = await tester.startGesture(pointAt(tester, 0.8));
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();

      expect(states.last.isDragging, isTrue);
      expect(states.last.activeThumbIndex, 1);
      expect(states.last.focusedThumbIndex, 1);

      await gesture.up();
    });
  });
}
