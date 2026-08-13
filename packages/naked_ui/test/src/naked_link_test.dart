import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import '../test_helpers.dart';

final _destination = Uri.parse('https://example.com/docs');

void main() {
  group('NakedLink public state contract', () {
    test('requires either a child or builder', () {
      expect(() => NakedLink(linkUrl: _destination), throwsAssertionError);
    });

    testWidgets('renders its child without a builder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NakedLink(
            linkUrl: _destination,
            child: const Text('Documentation'),
          ),
        ),
      );

      expect(find.text('Documentation'), findsOneWidget);
    });

    testWidgets('builder and scope receive one immutable state snapshot', (
      tester,
    ) async {
      final linkUrl = Uri.parse('https://example.com/docs');
      NakedLinkState? builderState;
      NakedLinkState? scopedState;
      Widget? receivedChild;

      await tester.pumpWidget(
        MaterialApp(
          home: NakedLink(
            linkUrl: linkUrl,
            child: const Text('Documentation'),
            builder: (context, state, child) {
              builderState = state;
              scopedState = NakedLinkState.of(context);
              receivedChild = child;
              return child!;
            },
          ),
        ),
      );

      expect(builderState, isNotNull);
      expect(scopedState, same(builderState));
      expect(receivedChild, isA<Text>());
      expect(builderState!.linkUrl, linkUrl);
      expect(builderState!.states, isEmpty);
      expect(
        () => builderState!.states.add(WidgetState.hovered),
        throwsUnsupportedError,
      );
      expect(builderState!.states, isEmpty);
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

  group('NakedLink resolver contract', () {
    testWidgets('nearest resolver follows the observer with the exact URI', (
      tester,
    ) async {
      final linkUrl = Uri.parse('custom-scheme:destination');
      final events = <String>[];

      await tester.pumpWidget(
        _testApp(
          NakedLinkResolver(
            resolve: (context, resolvedUrl) {
              events.add('outer:$resolvedUrl');
              expect(resolvedUrl, linkUrl);
              return NakedLinkResolution.handled;
            },
            child: NakedLinkResolver(
              resolve: (context, resolvedUrl) {
                events.add('inner:$resolvedUrl');
                expect(context, same(tester.element(find.byType(NakedLink))));
                return NakedLinkResolution.handled;
              },
              child: NakedLink(
                linkUrl: linkUrl,
                onActivated: (activatedUrl) {
                  events.add('observer:$activatedUrl');
                },
                child: const SizedBox(
                  width: 160,
                  height: 48,
                  child: Text('Link'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Link'));
      await tester.pump();

      expect(events, ['observer:$linkUrl', 'inner:$linkUrl']);
    });

    testWidgets('platformDefault falls through to platform navigation', (
      tester,
    ) async {
      final platformCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
      messenger.setMockMethodCallHandler(launcherChannel, (call) async {
        platformCalls.add(call);
        return true;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(launcherChannel, null),
      );

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            linkUrl: Uri.parse('https://example.com/platform-default'),
            child: const SizedBox(width: 160, height: 48, child: Text('Link')),
          ),
          resolve: (_, _) => NakedLinkResolution.platformDefault,
        ),
      );

      await tester.tap(find.text('Link'));
      await tester.pump();
      await tester.pump();

      expect(platformCalls.map((call) => call.method), contains('launch'));
    });

    testWidgets('no resolver is equivalent to platformDefault', (tester) async {
      final platformCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
      messenger.setMockMethodCallHandler(launcherChannel, (call) async {
        platformCalls.add(call);
        return true;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(launcherChannel, null),
      );

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            linkUrl: Uri.parse('https://example.com/no-resolver'),
            child: const SizedBox(width: 160, height: 48, child: Text('Link')),
          ),
          includeResolver: false,
        ),
      );

      await tester.tap(find.text('Link'));
      await tester.pump();
      await tester.pump();

      expect(platformCalls.map((call) => call.method), contains('launch'));
    });

    testWidgets('resolver exceptions surface without default fallback', (
      tester,
    ) async {
      final platformCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
      messenger.setMockMethodCallHandler(launcherChannel, (call) async {
        platformCalls.add(call);
        return true;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(launcherChannel, null),
      );
      final events = <String>[];

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            linkUrl: Uri.parse('https://example.com/resolver-error'),
            onActivated: (_) => events.add('observer'),
            child: const SizedBox(width: 160, height: 48, child: Text('Link')),
          ),
          resolve: (_, _) {
            events.add('resolver');
            throw StateError('resolver failure');
          },
        ),
      );

      await tester.tap(find.text('Link'));
      await tester.pump();

      expect(events, ['observer', 'resolver']);
      expect(tester.takeException(), isA<StateError>());
      expect(platformCalls, isEmpty);
    });

    testWidgets('disabled Link invokes neither observer nor resolver', (
      tester,
    ) async {
      var observerCalls = 0;
      var resolverCalls = 0;

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            enabled: false,
            linkUrl: Uri.parse('https://example.com/disabled'),
            onActivated: (_) => observerCalls++,
            child: const SizedBox(width: 160, height: 48, child: Text('Link')),
          ),
          resolve: (_, _) {
            resolverCalls++;
            return NakedLinkResolution.handled;
          },
        ),
      );

      await tester.tap(find.text('Link'));
      await tester.pump();

      expect(observerCalls, 0);
      expect(resolverCalls, 0);
    });
  });

  group('NakedLink activation contract', () {
    testWidgets('enabled is the only availability switch and retains the URI', (
      tester,
    ) async {
      const enabledKey = ValueKey('enabled');
      const explicitDisabledKey = ValueKey('explicit-disabled');
      var callbackCount = 0;
      NakedLinkState? enabledState;
      NakedLinkState? explicitDisabledState;

      await tester.pumpWidget(
        _testApp(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NakedLink(
                key: enabledKey,
                linkUrl: _destination,
                onActivated: (_) => callbackCount++,
                builder: (context, state, child) {
                  enabledState = state;
                  return const SizedBox(
                    width: 160,
                    height: 48,
                    child: Text('Enabled'),
                  );
                },
              ),
              NakedLink(
                key: explicitDisabledKey,
                enabled: false,
                linkUrl: Uri.parse('https://example.com/unavailable'),
                onActivated: (_) => callbackCount++,
                builder: (context, state, child) {
                  explicitDisabledState = state;
                  return const SizedBox(
                    width: 160,
                    height: 48,
                    child: Text('Explicitly disabled'),
                  );
                },
              ),
            ],
          ),
        ),
      );

      expect(enabledState!.isDisabled, isFalse);
      expect(enabledState!.linkUrl, _destination);
      expect(explicitDisabledState!.isDisabled, isTrue);
      expect(
        explicitDisabledState!.linkUrl,
        Uri.parse('https://example.com/unavailable'),
      );

      await tester.tap(find.byKey(explicitDisabledKey));
      await tester.pump();
      expect(callbackCount, 0);
      tester.expectCursor(SystemMouseCursors.click, on: enabledKey);
      tester.expectCursor(SystemMouseCursors.basic, on: explicitDisabledKey);
    });

    testWidgets('primary tap updates press state and activates exactly once', (
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
            linkUrl: _destination,
            onActivated: (_) => callbackCount++,
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
      expect(callbackCount, 0);

      await gesture.up();
      await tester.pump();
      expect(state!.isPressed, isFalse);
      expect(pressChanges, [true, false]);
      expect(callbackCount, 1);
    });

    testWidgets('canceled primary gesture clears press without activating', (
      tester,
    ) async {
      const linkKey = ValueKey('link');
      var callbackCount = 0;
      final pressChanges = <bool>[];

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            key: linkKey,
            linkUrl: _destination,
            onActivated: (_) => callbackCount++,
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
    });

    testWidgets('secondary and middle clicks remain unclaimed', (tester) async {
      const linkKey = ValueKey('link');
      var callbackCount = 0;
      final pressChanges = <bool>[];

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            key: linkKey,
            linkUrl: _destination,
            onActivated: (_) => callbackCount++,
            onPressChange: pressChanges.add,
            child: const SizedBox(width: 160, height: 48, child: Text('Link')),
          ),
        ),
      );

      await tester.tapAt(
        tester.getCenter(find.byKey(linkKey)),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(callbackCount, 0);
      expect(pressChanges, isEmpty);

      await tester.tapAt(
        tester.getCenter(find.byKey(linkKey)),
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await tester.pump();

      expect(callbackCount, 0);
      expect(pressChanges, isEmpty);
    });

    testWidgets(
      'modified primary activation bypasses the observer and resolver',
      (tester) async {
        const linkKey = ValueKey('link');
        var observerCalls = 0;
        var resolverCalls = 0;

        await tester.pumpWidget(
          _testApp(
            NakedLink(
              key: linkKey,
              linkUrl: Uri.parse('/modified-primary'),
              onActivated: (_) => observerCalls++,
              child: const SizedBox(
                width: 160,
                height: 48,
                child: Text('Link'),
              ),
            ),
            resolve: (_, _) {
              resolverCalls++;
              return NakedLinkResolution.handled;
            },
          ),
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tapAt(
          tester.getCenter(find.byKey(linkKey)),
          kind: PointerDeviceKind.mouse,
        );
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(observerCalls, 0);
        expect(resolverCalls, 0);
      },
    );

    testWidgets(
      'modifier pressed after pointer down keeps activation browser-owned',
      (tester) async {
        const linkKey = ValueKey('link');
        var observerCalls = 0;
        var resolverCalls = 0;

        await tester.pumpWidget(
          _testApp(
            NakedLink(
              key: linkKey,
              linkUrl: Uri.parse('/modified-after-down'),
              onActivated: (_) => observerCalls++,
              child: const SizedBox(
                width: 160,
                height: 48,
                child: Text('Link'),
              ),
            ),
            resolve: (_, _) {
              resolverCalls++;
              return NakedLinkResolution.handled;
            },
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(linkKey)),
          kind: PointerDeviceKind.mouse,
        );
        var pointerIsDown = true;
        addTearDown(() async {
          if (pointerIsDown) await gesture.cancel();
        });

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        try {
          await gesture.up();
          pointerIsDown = false;
          await tester.pump();

          expect(observerCalls, 0);
          expect(resolverCalls, 0);
        } finally {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        }
      },
    );

    testWidgets('Enter and Numpad Enter activate while Space does not', (
      tester,
    ) async {
      final focusNode = FocusNode(debugLabel: 'link test');
      addTearDown(focusNode.dispose);
      final events = <String>[];
      NakedLinkState? state;

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            focusNode: focusNode,
            linkUrl: _destination,
            onActivated: (_) => events.add('observer'),
            builder: (context, value, child) {
              state = value;
              return const SizedBox(
                width: 160,
                height: 48,
                child: Text('Link'),
              );
            },
          ),
          resolve: (_, _) {
            events.add('resolver');
            return NakedLinkResolution.handled;
          },
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(events, ['observer', 'resolver']);

      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.pump();
      expect(events, ['observer', 'resolver', 'observer', 'resolver']);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(events, ['observer', 'resolver', 'observer', 'resolver']);
      expect(state!.isPressed, isFalse);
    });

    testWidgets('a held Enter key activates only once per key sequence', (
      tester,
    ) async {
      final focusNode = FocusNode(debugLabel: 'repeating link');
      addTearDown(focusNode.dispose);
      var callbackCount = 0;

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            focusNode: focusNode,
            linkUrl: _destination,
            onActivated: (_) => callbackCount++,
            child: const Text('Link'),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(callbackCount, 1);
    });

    testWidgets('long-press selection wins over Link activation', (
      tester,
    ) async {
      var callbackCount = 0;

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            linkUrl: _destination,
            onActivated: (_) => callbackCount++,
            child: const SelectableText('Selectable documentation text'),
          ),
        ),
      );

      await tester.longPress(find.text('Selectable documentation text'));
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.selection.isCollapsed, isFalse);
      expect(callbackCount, 0);
    });

    testWidgets('feedback occurs only for accepted enabled activation', (
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
        var enabled = true;
        var feedback = true;
        late StateSetter rebuild;
        await tester.pumpWidget(
          _testApp(
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return NakedLink(
                  enabled: enabled,
                  enableFeedback: feedback,
                  linkUrl: _destination,
                  onActivated: (_) {},
                  child: const SizedBox(
                    width: 160,
                    height: 48,
                    child: Text('Link'),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Link'));
        await tester.pump();
        expect(
          platformCalls.where((call) => call.method == 'SystemSound.play'),
          hasLength(1),
        );
        rebuild(() => feedback = false);
        await tester.pump();
        await tester.tap(find.text('Link'));
        await tester.pump();
        expect(
          platformCalls.where((call) => call.method == 'SystemSound.play'),
          hasLength(1),
        );

        rebuild(() {
          feedback = true;
          enabled = false;
        });
        await tester.pump();
        await tester.tap(find.text('Link'));
        await tester.pump();
        expect(
          platformCalls.where((call) => call.method == 'SystemSound.play'),
          hasLength(1),
        );
      } finally {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        debugDefaultTargetPlatformOverride = oldPlatform;
      }
    });
  });

  group('NakedLink interaction state and lifecycle', () {
    testWidgets('hover and focus transitions update callbacks and scope', (
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
            linkUrl: _destination,
            onActivated: (_) {},
            onHoverChange: hoverChanges.add,
            onFocusChange: focusChanges.add,
            builder: (context, value, child) {
              state = NakedLinkState.of(context);
              expect(state, same(value));
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
      expect(focusNode.hasFocus, isTrue);
      expect(focusChanges, [true]);
      expect(state!.isFocused, isTrue);

      await mouse.moveTo(const Offset(-100, -100));
      await tester.pump();
      expect(state!.isHovered, isFalse);
      expect(hoverChanges, [true, false]);

      focusNode.unfocus();
      await tester.pump();
      await tester.pump();
      expect(state!.isFocused, isFalse);
      expect(focusChanges, [true, false]);
    });

    testWidgets('effective disabled state controls traversal and cursor', (
      tester,
    ) async {
      const enabledKey = ValueKey('enabled');
      const explicitDisabledKey = ValueKey('explicit-disabled');
      const customKey = ValueKey('custom');
      final enabledNode = FocusNode(debugLabel: 'enabled link');
      final explicitDisabledNode = FocusNode(debugLabel: 'explicit disabled');
      final nextNode = FocusNode(debugLabel: 'next');
      addTearDown(enabledNode.dispose);
      addTearDown(explicitDisabledNode.dispose);
      addTearDown(nextNode.dispose);

      await tester.pumpWidget(
        _testApp(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NakedLink(
                key: explicitDisabledKey,
                enabled: false,
                focusNode: explicitDisabledNode,
                linkUrl: _destination,
                onActivated: (_) {},
                child: const SizedBox(child: Text('Explicit disabled')),
              ),
              NakedLink(
                key: enabledKey,
                focusNode: enabledNode,
                linkUrl: _destination,
                onActivated: (_) {},
                child: const SizedBox(child: Text('Enabled')),
              ),
              NakedLink(
                key: customKey,
                mouseCursor: SystemMouseCursors.help,
                linkUrl: _destination,
                onActivated: (_) {},
                child: const SizedBox(child: Text('Custom')),
              ),
              TextButton(
                focusNode: nextNode,
                onPressed: () {},
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(enabledNode.hasFocus, isTrue);
      expect(explicitDisabledNode.hasFocus, isFalse);

      tester.expectCursor(SystemMouseCursors.click, on: enabledKey);
      tester.expectCursor(SystemMouseCursors.basic, on: explicitDisabledKey);
      tester.expectCursor(SystemMouseCursors.help, on: customKey);
    });

    testWidgets('disabled Link rejects focus in directional navigation', (
      tester,
    ) async {
      final focusNode = FocusNode(debugLabel: 'directional disabled Link');
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              navigationMode: NavigationMode.directional,
            ),
            child: NakedLink(
              enabled: false,
              focusNode: focusNode,
              linkUrl: _destination,
              onActivated: (_) {},
              child: const Text('Unavailable Link'),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('disabling retains the destination and clears hover', (
      tester,
    ) async {
      const linkKey = ValueKey('link');
      final focusNode = FocusNode(debugLabel: 'dynamic link');
      addTearDown(focusNode.dispose);
      final hoverChanges = <bool>[];
      var callbackCount = 0;
      var enabled = true;
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
                enabled: enabled,
                linkUrl: _destination,
                onActivated: (_) => callbackCount++,
                onHoverChange: hoverChanges.add,
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
      await tester.pump();
      expect(state!.isHovered, isTrue);

      focusNode.requestFocus();
      await tester.pump();
      rebuild(() => enabled = false);
      await tester.pump();

      expect(state!.isDisabled, isTrue);
      expect(state!.linkUrl, _destination);
      expect(state!.isHovered, isFalse);
      expect(state!.isPressed, isFalse);
      expect(hoverChanges, [true, false]);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.text('Link'));
      await tester.pump();
      expect(callbackCount, 0);
      tester.expectCursor(SystemMouseCursors.basic, on: linkKey);
    });

    testWidgets('disabling while hovered permits a parent-setState callback', (
      tester,
    ) async {
      const linkKey = ValueKey('link');
      var enabled = true;
      var hovered = false;
      late StateSetter rebuild;

      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedLink(
                key: linkKey,
                enabled: enabled,
                linkUrl: Uri.parse('https://example.com/docs'),
                onActivated: (_) {},
                onHoverChange: (value) => setState(() => hovered = value),
                child: const SizedBox(
                  width: 160,
                  height: 48,
                  child: Text('Link'),
                ),
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
      expect(hovered, isTrue);

      rebuild(() => enabled = false);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(hovered, isFalse);
    });

    testWidgets('disabling while pressed permits a parent-setState callback', (
      tester,
    ) async {
      const linkKey = ValueKey('link');
      var enabled = true;
      var pressed = false;
      late StateSetter rebuild;

      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedLink(
                key: linkKey,
                enabled: enabled,
                linkUrl: Uri.parse('https://example.com/docs'),
                onActivated: (_) {},
                onPressChange: (value) => setState(() => pressed = value),
                child: const SizedBox(
                  width: 160,
                  height: 48,
                  child: Text('Link'),
                ),
              );
            },
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(linkKey)),
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.cancel);
      await tester.pump();
      expect(pressed, isTrue);

      rebuild(() => enabled = false);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(pressed, isFalse);
    });

    testWidgets('reenabling under a stationary pointer restores hover', (
      tester,
    ) async {
      const linkKey = ValueKey('link');
      var enabled = true;
      final hoverChanges = <bool>[];
      NakedLinkState? state;
      late StateSetter rebuild;

      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedLink(
                key: linkKey,
                enabled: enabled,
                linkUrl: Uri.parse('https://example.com/docs'),
                onActivated: (_) {},
                onHoverChange: hoverChanges.add,
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
      await tester.pump();
      expect(state!.isHovered, isTrue);

      rebuild(() => enabled = false);
      await tester.pump();
      await tester.pump();
      expect(state!.isHovered, isFalse);

      rebuild(() => enabled = true);
      await tester.pump();
      await tester.pump();

      expect(state!.isHovered, isTrue);
      expect(hoverChanges, [true, false, true]);
    });

    testWidgets('availability changes preserve the stateful child subtree', (
      tester,
    ) async {
      var enabled = true;
      var initCount = 0;
      var disposeCount = 0;
      late StateSetter rebuild;

      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedLink(
                enabled: enabled,
                linkUrl: _destination,
                onActivated: (_) {},
                child: _LifecycleProbe(
                  onInit: () => initCount++,
                  onDispose: () => disposeCount++,
                ),
              );
            },
          ),
        ),
      );

      expect(initCount, 1);
      expect(disposeCount, 0);

      rebuild(() => enabled = false);
      await tester.pump();
      rebuild(() => enabled = true);
      await tester.pump();

      expect(initCount, 1);
      expect(disposeCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(disposeCount, 1);
    });

    testWidgets(
      'autofocus works and focus-node replacement preserves ownership',
      (tester) async {
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
                  linkUrl: _destination,
                  onActivated: (_) {},
                  child: const SizedBox(child: Text('Link')),
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
      },
    );
  });
}

Widget _testApp(
  Widget child, {
  NakedLinkResolveCallback? resolve,
  bool includeResolver = true,
}) {
  final content = includeResolver
      ? NakedLinkResolver(
          resolve: resolve ?? (_, _) => NakedLinkResolution.handled,
          child: child,
        )
      : child;
  return MaterialApp(
    home: Scaffold(body: Center(child: content)),
  );
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.onInit, required this.onDispose});

  final VoidCallback onInit;
  final VoidCallback onDispose;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('Stateful child');
}
