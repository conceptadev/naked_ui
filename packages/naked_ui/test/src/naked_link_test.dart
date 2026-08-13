import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import '../test_helpers.dart';

void main() {
  group('NakedLink public contract', () {
    test('requires either a child or builder', () {
      expect(() => NakedLink(onPressed: () {}), throwsAssertionError);
    });

    testWidgets('works without a Material ancestor and exposes state', (
      tester,
    ) async {
      final linkUrl = Uri.parse('https://example.com/docs');
      NakedLinkState? builderState;
      NakedLinkState? scopedState;

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xffffffff),
          builder: (context, child) => Center(
            child: NakedLink(
              linkUrl: linkUrl,
              onPressed: () {},
              child: const Text('Documentation'),
              builder: (context, state, child) {
                builderState = state;
                scopedState = NakedLinkState.of(context);
                return child!;
              },
            ),
          ),
        ),
      );

      expect(find.text('Documentation'), findsOneWidget);
      expect(scopedState, same(builderState));
      expect(builderState!.linkUrl, linkUrl);
      expect(builderState!.states, isEmpty);
      expect(
        () => builderState!.states.add(WidgetState.hovered),
        throwsUnsupportedError,
      );
    });

    test('state equality and hash include states and URL metadata', () {
      final first = NakedLinkState(
        states: const {WidgetState.hovered, WidgetState.focused},
        linkUrl: Uri.parse('https://example.com/docs'),
      );
      final reordered = NakedLinkState(
        states: const {WidgetState.focused, WidgetState.hovered},
        linkUrl: Uri.parse('https://example.com/docs'),
      );
      final otherUrl = NakedLinkState(
        states: const {WidgetState.hovered, WidgetState.focused},
        linkUrl: Uri.parse('https://example.com/support'),
      );

      expect(first, reordered);
      expect(first.hashCode, reordered.hashCode);
      expect(first, isNot(otherUrl));
    });
  });

  group('NakedLink activation', () {
    testWidgets('primary tap updates press state and activates once', (
      tester,
    ) async {
      const linkKey = ValueKey('link');
      var callbackCount = 0;
      final pressChanges = <bool>[];
      NakedLinkState? state;

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            key: linkKey,
            onPressed: () => callbackCount++,
            onPressChange: pressChanges.add,
            builder: (context, value, child) {
              state = value;
              return const SizedBox(
                width: 160,
                height: 48,
                child: Text('Link'),
              );
            },
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(linkKey)),
      );
      await tester.pump();
      expect(state!.isPressed, isTrue);
      expect(pressChanges, [true]);

      await gesture.up();
      await tester.pump();
      expect(state!.isPressed, isFalse);
      expect(pressChanges, [true, false]);
      expect(callbackCount, 1);
    });

    testWidgets('canceled and secondary gestures do not activate', (
      tester,
    ) async {
      const linkKey = ValueKey('link');
      var callbackCount = 0;
      final pressChanges = <bool>[];

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            key: linkKey,
            onPressed: () => callbackCount++,
            onPressChange: pressChanges.add,
            child: const SizedBox(width: 160, height: 48, child: Text('Link')),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(linkKey)),
      );
      await tester.pump();
      await gesture.moveTo(const Offset(-100, -100));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(pressChanges, [true, false]);
      expect(callbackCount, 0);

      await tester.tapAt(
        tester.getCenter(find.byKey(linkKey)),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      expect(pressChanges, [true, false]);
      expect(callbackCount, 0);
    });

    testWidgets('Enter keys activate, repeats and Space do not', (
      tester,
    ) async {
      final focusNode = FocusNode(debugLabel: 'link activation');
      addTearDown(focusNode.dispose);
      var callbackCount = 0;

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            focusNode: focusNode,
            onPressed: () => callbackCount++,
            child: const Text('Link'),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(callbackCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(callbackCount, 2);
    });

    testWidgets('feedback occurs only for accepted opted-in activation', (
      tester,
    ) async {
      final oldPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final platformCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call);
        return null;
      });

      try {
        var enableFeedback = true;
        late StateSetter rebuild;
        await tester.pumpWidget(
          _testApp(
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return NakedLink(
                  enableFeedback: enableFeedback,
                  onPressed: () {},
                  child: const Text('Link'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Link'));
        await tester.pump();
        expect(_systemSoundCalls(platformCalls), hasLength(1));

        rebuild(() => enableFeedback = false);
        await tester.pump();
        await tester.tap(find.text('Link'));
        await tester.pump();
        expect(_systemSoundCalls(platformCalls), hasLength(1));
      } finally {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        debugDefaultTargetPlatformOverride = oldPlatform;
      }
    });
  });

  group('NakedLink interaction state and lifecycle', () {
    testWidgets('hover and focus update callbacks and builder state', (
      tester,
    ) async {
      const linkKey = ValueKey('link');
      final focusNode = FocusNode(debugLabel: 'link hover focus');
      addTearDown(focusNode.dispose);
      final hoverChanges = <bool>[];
      final focusChanges = <bool>[];
      NakedLinkState? state;

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            key: linkKey,
            focusNode: focusNode,
            onPressed: () {},
            onHoverChange: hoverChanges.add,
            onFocusChange: focusChanges.add,
            builder: (context, value, child) {
              state = value;
              return const SizedBox(
                width: 160,
                height: 48,
                child: Text('Link'),
              );
            },
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(linkKey)));
      await tester.pump();
      expect(state!.isHovered, isTrue);
      expect(hoverChanges, [true]);

      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(state!.isFocused, isTrue);
      expect(focusChanges, [true]);

      await mouse.moveTo(const Offset(-100, -100));
      focusNode.unfocus();
      await tester.pump();
      await tester.pump();
      expect(state!.isHovered, isFalse);
      expect(state!.isFocused, isFalse);
      expect(hoverChanges, [true, false]);
      expect(focusChanges, [true, false]);
    });

    testWidgets('effective disabled state blocks traversal and activation', (
      tester,
    ) async {
      const explicitKey = ValueKey('explicit-disabled');
      const callbackKey = ValueKey('callback-disabled');
      const enabledKey = ValueKey('enabled');
      final explicitNode = FocusNode(debugLabel: 'explicit disabled');
      final callbackNode = FocusNode(debugLabel: 'callback disabled');
      final enabledNode = FocusNode(debugLabel: 'enabled');
      addTearDown(explicitNode.dispose);
      addTearDown(callbackNode.dispose);
      addTearDown(enabledNode.dispose);
      var callbackCount = 0;

      await tester.pumpWidget(
        _testApp(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NakedLink(
                key: explicitKey,
                enabled: false,
                focusNode: explicitNode,
                onPressed: () => callbackCount++,
                child: const Text('Explicit disabled'),
              ),
              NakedLink(
                key: callbackKey,
                focusNode: callbackNode,
                child: const Text('Callback disabled'),
              ),
              NakedLink(
                key: enabledKey,
                focusNode: enabledNode,
                onPressed: () => callbackCount++,
                child: const Text('Enabled'),
              ),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(enabledNode.hasFocus, isTrue);
      expect(explicitNode.hasFocus, isFalse);
      expect(callbackNode.hasFocus, isFalse);

      await tester.tap(find.text('Explicit disabled'));
      await tester.tap(find.text('Callback disabled'));
      await tester.pump();
      expect(callbackCount, 0);
      tester.expectCursor(SystemMouseCursors.basic, on: explicitKey);
      tester.expectCursor(SystemMouseCursors.basic, on: callbackKey);
      tester.expectCursor(SystemMouseCursors.click, on: enabledKey);
    });

    testWidgets('callback removal disables and clears interaction state', (
      tester,
    ) async {
      const linkKey = ValueKey('link');
      final focusNode = FocusNode(debugLabel: 'dynamic link');
      addTearDown(focusNode.dispose);
      final hoverChanges = <bool>[];
      final focusChanges = <bool>[];
      final pressChanges = <bool>[];
      VoidCallback? callback = () {};
      NakedLinkState? state;
      late StateSetter rebuild;

      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedLink(
                key: linkKey,
                focusNode: focusNode,
                onPressed: callback,
                onHoverChange: hoverChanges.add,
                onFocusChange: focusChanges.add,
                onPressChange: pressChanges.add,
                builder: (context, value, child) {
                  state = value;
                  return const SizedBox(
                    width: 160,
                    height: 48,
                    child: Text('Link'),
                  );
                },
              );
            },
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(linkKey)));
      focusNode.requestFocus();
      await tester.pump();
      expect(state!.isHovered, isTrue);
      expect(state!.isFocused, isTrue);

      final press = await tester.startGesture(
        tester.getCenter(find.byKey(linkKey)),
      );
      await tester.pump();
      expect(state!.isPressed, isTrue);

      rebuild(() => callback = null);
      await tester.pump();
      await tester.pump();

      expect(state!.isDisabled, isTrue);
      expect(state!.isHovered, isFalse);
      expect(state!.isFocused, isFalse);
      expect(state!.isPressed, isFalse);
      expect(hoverChanges, [true, false]);
      expect(focusChanges, [true, false]);
      expect(pressChanges, [true, false]);
      expect(tester.takeException(), isNull);
      await press.cancel();
    });

    testWidgets('focus node replacement preserves caller ownership', (
      tester,
    ) async {
      final firstNode = FocusNode(debugLabel: 'first external link');
      final secondNode = FocusNode(debugLabel: 'second external link');
      addTearDown(firstNode.dispose);
      addTearDown(secondNode.dispose);
      var currentNode = firstNode;
      late StateSetter rebuild;

      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedLink(
                autofocus: true,
                focusNode: currentNode,
                onPressed: () {},
                child: const Text('Link'),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(firstNode.hasFocus, isTrue);

      rebuild(() => currentNode = secondNode);
      await tester.pump();
      await tester.pump();
      expect(firstNode.hasFocus, isFalse);
      expect(secondNode.hasFocus, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      final listener = () {};
      expect(() => firstNode.addListener(listener), returnsNormally);
      firstNode.removeListener(listener);
      expect(() => secondNode.addListener(listener), returnsNormally);
      secondNode.removeListener(listener);
    });
  });
}

Iterable<MethodCall> _systemSoundCalls(Iterable<MethodCall> calls) =>
    calls.where((call) => call.method == 'SystemSound.play');

Widget _testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}
