import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

Future<void> _pumpField(
  WidgetTester tester, {
  required TextEditingController controller,
  required _PressChanges changes,
  int? minLines,
  int? maxLines = 1,
  ScrollController? scrollController,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: NakedTextField(
              controller: controller,
              minLines: minLines,
              maxLines: maxLines,
              scrollController: scrollController,
              onTapChange: changes.tap.add,
              onPressChange: changes.aggregate.add,
              builder: (context, state, editable) => editable,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _PressChanges {
  final tap = <bool>[];
  final aggregate = <bool>[];

  void expectBoth(List<bool> expected) {
    expect(tap, expected);
    expect(aggregate, expected);
  }
}

void main() {
  testWidgets(
    'double tap releases press when word selection takes ownership',
    (tester) async {
      final controller = TextEditingController(text: 'Select this word');
      final changes = _PressChanges();
      addTearDown(controller.dispose);

      await _pumpField(tester, controller: controller, changes: changes);

      final editable = find.byType(EditableText);
      await tester.tap(editable);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(editable);
      await tester.pump();

      expect(controller.selection.isCollapsed, isFalse);
      changes.expectBoth([true, false, true, false]);
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'triple tap releases press when paragraph selection owns the gesture',
    (tester) async {
      final controller = TextEditingController(text: 'Select this paragraph');
      final changes = _PressChanges();
      addTearDown(controller.dispose);

      await _pumpField(tester, controller: controller, changes: changes);

      final editable = find.byType(EditableText);
      for (var index = 0; index < 3; index++) {
        await tester.tap(editable);
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 21),
      );
      changes.expectBoth([true, false, true, false, true, false]);
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'long press releases press when long-press selection owns the gesture',
    (tester) async {
      final controller = TextEditingController(text: 'Select this word');
      final changes = _PressChanges();
      addTearDown(controller.dispose);

      await _pumpField(tester, controller: controller, changes: changes);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(EditableText)),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(kPressTimeout);
      changes.expectBoth([true]);

      await tester.pump(kLongPressTimeout);
      changes.expectBoth([true, false]);

      await gesture.up();
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'force press releases press when force selection owns the gesture',
    (tester) async {
      final controller = TextEditingController(text: 'Select this word');
      final changes = _PressChanges();
      addTearDown(controller.dispose);

      await _pumpField(tester, controller: controller, changes: changes);

      final position = tester.getCenter(find.byType(EditableText));
      final pointer = tester.nextPointer;
      final gesture = await tester.createGesture();
      await gesture.downWithCustomEvent(
        position,
        PointerDownEvent(
          pointer: pointer,
          position: position,
          pressure: 0,
          pressureMin: 0,
          pressureMax: 6,
        ),
      );
      await tester.pump(kPressTimeout);
      changes.expectBoth([true]);

      await gesture.updateWithCustomEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: position,
          pressure: 0.5,
          pressureMin: 0,
        ),
      );
      await tester.pump();

      expect(controller.selection.isCollapsed, isFalse);
      changes.expectBoth([true, false]);

      await gesture.up();
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'mouse selection drag releases press when selection owns the gesture',
    (tester) async {
      final controller = TextEditingController(
        text: 'Drag across this editable text to select it',
      );
      final changes = _PressChanges();
      addTearDown(controller.dispose);

      await _pumpField(tester, controller: controller, changes: changes);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(EditableText)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(kPressTimeout);
      changes.expectBoth([true]);

      await gesture.moveBy(const Offset(50, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      expect(controller.selection.isCollapsed, isFalse);
      changes.expectBoth([true, false]);

      await gesture.up();
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'multiline touch scroll releases press when scrolling owns the gesture',
    (tester) async {
      final controller = TextEditingController(
        text: List.generate(12, (index) => 'Line $index').join('\n'),
      );
      final scrollController = ScrollController();
      final changes = _PressChanges();
      addTearDown(controller.dispose);
      addTearDown(scrollController.dispose);

      await _pumpField(
        tester,
        controller: controller,
        minLines: 2,
        maxLines: 2,
        scrollController: scrollController,
        changes: changes,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(EditableText)),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(kPressTimeout);
      changes.expectBoth([true]);

      await gesture.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      expect(scrollController.offset, greaterThan(0));
      changes.expectBoth([true, false]);

      await gesture.up();
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('disabling during a press clears both pressed callbacks', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Disable while pressed');
    final changes = _PressChanges();
    var enabled = true;
    var states = <WidgetState>{};
    var callbackRebuilds = 0;
    late StateSetter setHostState;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return NakedTextField(
              controller: controller,
              enabled: enabled,
              onTapChange: changes.tap.add,
              onPressChange: (pressed) {
                changes.aggregate.add(pressed);
                if (!pressed) {
                  setHostState(() => callbackRebuilds++);
                }
              },
              builder: (context, state, editable) {
                states = state.states;
                return editable;
              },
            );
          },
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(EditableText)),
    );
    await tester.pump(kPressTimeout);
    changes.expectBoth([true]);
    expect(states, contains(WidgetState.pressed));

    setHostState(() => enabled = false);
    await tester.pump();
    changes.expectBoth([true, false]);
    expect(callbackRebuilds, 1);
    expect(states, contains(WidgetState.disabled));
    expect(states, isNot(contains(WidgetState.pressed)));

    await tester.pump();

    await gesture.up();
    await tester.pump();
    changes.expectBoth([true, false]);

    setHostState(() => enabled = true);
    await tester.pump();
    changes.expectBoth([true, false]);
    expect(states, isNot(contains(WidgetState.disabled)));
    expect(states, isNot(contains(WidgetState.pressed)));
  });

  testWidgets(
    'disabled pointer gestures do not select or focus the field',
    (tester) async {
      final controller = TextEditingController.fromValue(
        const TextEditingValue(
          text: 'Disabled field text',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
      final focusNode = FocusNode();
      final changes = _PressChanges();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              navigationMode: NavigationMode.directional,
            ),
            child: NakedTextField(
              controller: controller,
              focusNode: focusNode,
              enabled: false,
              onTapChange: changes.tap.add,
              onPressChange: changes.aggregate.add,
              builder: (context, state, editable) => editable,
            ),
          ),
        ),
      );

      final editable = find.byType(EditableText);
      final position = tester.getCenter(editable);
      await tester.tapAt(position);
      await tester.pump(kDoubleTapTimeout ~/ 2);
      await tester.tapAt(position);
      await tester.pump();

      final drag = await tester.startGesture(
        position,
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveBy(const Offset(60, 0));
      await tester.pump();
      await drag.up();
      await tester.pump();

      expect(controller.selection, const TextSelection.collapsed(offset: 0));
      expect(focusNode.hasFocus, isFalse);
      changes.expectBoth(const []);
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'disabled force press does not select or focus the field',
    (tester) async {
      final controller = TextEditingController.fromValue(
        const TextEditingValue(
          text: 'Disabled force press',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
      final focusNode = FocusNode();
      final changes = _PressChanges();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: NakedTextField(
            controller: controller,
            focusNode: focusNode,
            enabled: false,
            onTapChange: changes.tap.add,
            onPressChange: changes.aggregate.add,
            builder: (context, state, editable) => editable,
          ),
        ),
      );

      final position = tester.getCenter(find.byType(EditableText));
      final pointer = tester.nextPointer;
      final gesture = await tester.createGesture();
      await gesture.downWithCustomEvent(
        position,
        PointerDownEvent(
          pointer: pointer,
          position: position,
          pressure: 0,
          pressureMin: 0,
          pressureMax: 6,
        ),
      );
      await tester.pump(kPressTimeout);
      await gesture.updateWithCustomEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: position,
          pressure: 0.5,
          pressureMin: 0,
        ),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(controller.selection, const TextSelection.collapsed(offset: 0));
      expect(focusNode.hasFocus, isFalse);
      changes.expectBoth(const []);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
