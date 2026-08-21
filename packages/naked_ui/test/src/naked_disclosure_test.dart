import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import '../test_helpers.dart';

void main() {
  group('state ownership', () {
    testWidgets('starts collapsed or from defaultExpanded', (tester) async {
      await tester.pumpMaterialWidget(
        const Column(
          children: [
            NakedDisclosure(child: Text('Closed'), panel: Text('Hidden')),
            NakedDisclosure(
              defaultExpanded: true,
              child: Text('Open'),
              panel: Text('Visible'),
            ),
          ],
        ),
      );

      expect(find.text('Hidden'), findsNothing);
      expect(find.text('Visible'), findsOneWidget);
    });

    testWidgets('ignores later defaultExpanded changes', (tester) async {
      var defaultExpanded = false;
      late StateSetter rebuild;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedDisclosure(
              defaultExpanded: defaultExpanded,
              child: const Text('Trigger'),
              panel: const Text('Panel'),
            );
          },
        ),
      );

      rebuild(() => defaultExpanded = true);
      await tester.pump();
      expect(find.text('Panel'), findsNothing);
    });

    testWidgets('uncontrolled activation updates before notifying', (
      tester,
    ) async {
      final requested = <bool>[];
      late NakedDisclosureState state;
      await tester.pumpMaterialWidget(
        NakedDisclosure(
          onExpandedChanged: (value) {
            requested.add(value);
            expect(state.isExpanded, isFalse);
          },
          builder: (context, value, _) {
            state = value;
            return const Text('Trigger');
          },
          panel: const Text('Panel'),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(requested, [true]);
      expect(state.isExpanded, isTrue);
      expect(find.text('Panel'), findsOneWidget);
    });

    testWidgets('uncontrolled disclosure toggles without callback', (
      tester,
    ) async {
      await tester.pumpMaterialWidget(
        const NakedDisclosure(child: Text('Trigger'), panel: Text('Panel')),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(find.text('Panel'), findsOneWidget);
      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(find.text('Panel'), findsNothing);
    });

    testWidgets('controlled requests can be rejected or accepted by owner', (
      tester,
    ) async {
      var expanded = false;
      final requests = <bool>[];
      late StateSetter rebuild;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedDisclosure(
              expanded: expanded,
              onExpandedChanged: requests.add,
              child: const Text('Trigger'),
              panel: const Text('Panel'),
            );
          },
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(requests, [true]);
      expect(find.text('Panel'), findsNothing);

      rebuild(() => expanded = true);
      await tester.pump();
      expect(find.text('Panel'), findsOneWidget);
    });

    testWidgets('controlled to uncontrolled preserves last accepted value', (
      tester,
    ) async {
      bool? expanded = true;
      late StateSetter rebuild;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedDisclosure(
              expanded: expanded,
              onExpandedChanged: (_) {},
              child: const Text('Trigger'),
              panel: const Text('Panel'),
            );
          },
        ),
      );

      rebuild(() => expanded = null);
      await tester.pump();
      expect(find.text('Panel'), findsOneWidget);
      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(find.text('Panel'), findsNothing);
    });

    testWidgets('controlled disclosure without callback is read-only', (
      tester,
    ) async {
      late NakedDisclosureState state;
      await tester.pumpMaterialWidget(
        NakedDisclosure(
          expanded: true,
          builder: (_, value, _) {
            state = value;
            return const Text('Trigger');
          },
          panel: const Text('Panel'),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(state.isDisabled, isTrue);
      expect(state.isExpanded, isTrue);
      expect(find.text('Panel'), findsOneWidget);
    });
  });

  group('interaction and shared state', () {
    testWidgets('activates with pointer, Enter, Space, and numpad Enter', (
      tester,
    ) async {
      var expanded = false;
      final requested = <bool>[];
      late StateSetter rebuild;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedDisclosure(
              autofocus: true,
              expanded: expanded,
              onExpandedChanged: (value) {
                requested.add(value);
                rebuild(() => expanded = value);
              },
              child: const Text('Trigger'),
              panel: const Text('Panel'),
            );
          },
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.pump();
      expect(requested, [true, false, true, false]);
    });

    testWidgets('semantic activation toggles and keyboard focus is retained', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final semantics = tester.ensureSemantics();
      await tester.pumpMaterialWidget(
        NakedDisclosure(
          focusNode: focusNode,
          child: const Text('Trigger'),
          panel: const Text('Panel'),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      final triggerSemantics = tester.getSemantics(find.text('Trigger'));
      triggerSemantics.owner!.performAction(
        triggerSemantics.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(find.text('Panel'), findsOneWidget);
      expect(focusNode.hasFocus, isTrue);
      semantics.dispose();
    });

    testWidgets('keyboard press feedback lasts 100ms', (tester) async {
      late NakedDisclosureState state;
      final changes = <bool>[];
      await tester.pumpMaterialWidget(
        NakedDisclosure(
          autofocus: true,
          onPressChange: changes.add,
          builder: (_, value, _) {
            state = value;
            return const Text('Trigger');
          },
          panel: const Text('Panel'),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(state.isPressed, isTrue);
      await tester.pump(const Duration(milliseconds: 99));
      expect(state.isPressed, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state.isPressed, isFalse);
      expect(changes, [true, false]);
    });

    testWidgets('becoming read-only clears an active keyboard press', (
      tester,
    ) async {
      ValueChanged<bool>? callback = (_) {};
      late StateSetter rebuild;
      late NakedDisclosureState state;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedDisclosure(
              autofocus: true,
              expanded: false,
              onExpandedChanged: callback,
              builder: (_, value, _) {
                state = value;
                return const Text('Trigger');
              },
              panel: const Text('Panel'),
            );
          },
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(state.isPressed, isTrue);
      rebuild(() => callback = null);
      await tester.pump();
      expect(state.isPressed, isFalse);
      expect(state.isDisabled, isTrue);
      await tester.pump(const Duration(milliseconds: 150));
      expect(state.isPressed, isFalse);
    });

    testWidgets('replaces focus nodes while preserving focus', (tester) async {
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      var node = first;
      late StateSetter rebuild;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedDisclosure(
              focusNode: node,
              child: const Text('Trigger'),
              panel: const Text('Panel'),
            );
          },
        ),
      );

      first.requestFocus();
      await tester.pump();
      rebuild(() => node = second);
      await tester.pump();
      await tester.pump();
      expect(second.hasFocus, isTrue);
    });

    testWidgets('shares state and controller through every builder', (
      tester,
    ) async {
      final states = <NakedDisclosureState>[];
      final controllers = <WidgetStatesController>[];
      await tester.pumpMaterialWidget(
        NakedDisclosure(
          defaultExpanded: true,
          child: const Text('Static'),
          builder: (context, state, child) {
            states.add(state);
            controllers.add(NakedDisclosureState.controllerOf(context));
            return child!;
          },
          panel: Builder(
            builder: (context) {
              states.add(NakedDisclosureState.of(context));
              controllers.add(NakedDisclosureState.controllerOf(context));
              return const Text('Panel');
            },
          ),
          transitionBuilder: (context, animation, child) {
            states.add(NakedDisclosureState.of(context));
            controllers.add(NakedDisclosureState.controllerOf(context));
            return child;
          },
          itemBuilder: (context, state, child) {
            states.add(state);
            controllers.add(NakedDisclosureState.controllerOf(context));
            return child!;
          },
        ),
      );

      expect(states, hasLength(4));
      expect(states.every((state) => identical(state, states.first)), isTrue);
      expect(
        controllers.every(
          (controller) => identical(controller, controllers.first),
        ),
        isTrue,
      );
      expect(states.first.isSelected, isTrue);
    });

    testWidgets('semantic exclusion preserves panel and controller identity', (
      tester,
    ) async {
      var excludeSemantics = false;
      var initializations = 0;
      var disposals = 0;
      WidgetStatesController? controller;
      late WidgetStatesController latestController;
      late StateSetter rebuild;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedDisclosure(
              defaultExpanded: true,
              excludeSemantics: excludeSemantics,
              builder: (context, state, child) {
                latestController = NakedDisclosureState.controllerOf(context);
                controller ??= latestController;
                return child!;
              },
              child: const Text('Trigger'),
              panel: _PanelLifecycleProbe(
                onInitialized: () => initializations++,
                onDisposed: () => disposals++,
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Panel 0'));
      await tester.pump();
      expect(find.text('Panel 1'), findsOneWidget);

      rebuild(() => excludeSemantics = true);
      await tester.pump();
      expect(find.text('Panel 1'), findsOneWidget);
      expect(identical(latestController, controller), isTrue);
      expect(initializations, 1);
      expect(disposals, 0);

      rebuild(() => excludeSemantics = false);
      await tester.pump();
      expect(find.text('Panel 1'), findsOneWidget);
      expect(identical(latestController, controller), isTrue);
      expect(initializations, 1);
      expect(disposals, 0);
    });

    testWidgets('reports hover, focus, press, selected, and disabled states', (
      tester,
    ) async {
      const key = Key('disclosure');
      late NakedDisclosureState state;
      var enabled = true;
      late StateSetter rebuild;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedDisclosure(
              key: key,
              enabled: enabled,
              builder: (_, value, _) {
                state = value;
                return const SizedBox(width: 100, height: 40);
              },
              panel: const Text('Panel'),
            );
          },
        ),
      );

      await tester.simulateHover(
        key,
        onHover: () => expect(state.isHovered, isTrue),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pump();
      expect(state.isPressed, isTrue);
      await gesture.up();
      await tester.pump();
      expect(state.isSelected, isTrue);

      rebuild(() => enabled = false);
      await tester.pump();
      expect(state.isDisabled, isTrue);
    });

    testWidgets('panel controls do not toggle the disclosure', (tester) async {
      var panelPresses = 0;
      await tester.pumpMaterialWidget(
        NakedDisclosure(
          defaultExpanded: true,
          child: const Text('Trigger'),
          panel: TextButton(
            onPressed: () => panelPresses++,
            child: const Text('Panel action'),
          ),
        ),
      );

      await tester.tap(find.text('Panel action'));
      await tester.pump();
      expect(panelPresses, 1);
      expect(find.text('Panel action'), findsOneWidget);
    });

    testWidgets(
      'expanded panel participates in traversal and closing excludes it',
      (tester) async {
        final triggerFocus = FocusNode();
        final firstPanelFocus = FocusNode();
        final secondPanelFocus = FocusNode();
        final afterFocus = FocusNode();
        addTearDown(triggerFocus.dispose);
        addTearDown(firstPanelFocus.dispose);
        addTearDown(secondPanelFocus.dispose);
        addTearDown(afterFocus.dispose);
        var expanded = true;
        var panelPresses = 0;
        late StateSetter rebuild;
        await tester.pumpMaterialWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Column(
                children: [
                  NakedDisclosure(
                    expanded: expanded,
                    onExpandedChanged: (_) {},
                    focusNode: triggerFocus,
                    child: const Text('Trigger'),
                    panel: Column(
                      children: [
                        TextButton(
                          focusNode: firstPanelFocus,
                          onPressed: () => panelPresses++,
                          child: const Text('Panel action 1'),
                        ),
                        TextButton(
                          focusNode: secondPanelFocus,
                          onPressed: () => panelPresses++,
                          child: const Text('Panel action 2'),
                        ),
                      ],
                    ),
                    transitionBuilder: (context, animation, child) =>
                        FadeTransition(opacity: animation, child: child),
                  ),
                  TextButton(
                    focusNode: afterFocus,
                    onPressed: () {},
                    child: const Text('After'),
                  ),
                ],
              );
            },
          ),
        );

        triggerFocus.requestFocus();
        await tester.pump();
        triggerFocus.nextFocus();
        await tester.pump();
        expect(firstPanelFocus.hasFocus, isTrue);

        firstPanelFocus.nextFocus();
        await tester.pump();
        expect(secondPanelFocus.hasFocus, isTrue);

        secondPanelFocus.nextFocus();
        await tester.pump();
        expect(afterFocus.hasFocus, isTrue);

        secondPanelFocus.requestFocus();
        await tester.pump();
        rebuild(() => expanded = false);
        await tester.pump();
        expect(secondPanelFocus.hasFocus, isFalse);
        expect(triggerFocus.hasFocus, isTrue);
        expect(find.text('Panel action 1'), findsOneWidget);
        await tester.tap(find.text('Panel action 1'), warnIfMissed: false);
        await tester.pump();
        expect(panelPresses, 0);
      },
    );
  });

  group('panel lifecycle', () {
    testWidgets('mounts and unmounts immediately without transition', (
      tester,
    ) async {
      await tester.pumpMaterialWidget(
        const NakedDisclosure(child: Text('Trigger'), panel: Text('Panel')),
      );
      expect(find.text('Panel'), findsNothing);
      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(find.text('Panel'), findsOneWidget);
      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(find.text('Panel'), findsNothing);
    });

    testWidgets('retains exit content, excludes it, then removes it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      bool panelIsAccessible() => tester.semantics
          .simulatedAccessibilityTraversal()
          .any((node) => node.getSemanticsData().label == 'Panel');
      late Animation<double> animation;
      await tester.pumpMaterialWidget(
        NakedDisclosure(
          defaultExpanded: true,
          child: const Text('Trigger'),
          panel: const Text('Panel'),
          transitionBuilder: (context, value, child) {
            animation = value;
            return FadeTransition(opacity: value, child: child);
          },
        ),
      );
      expect(animation.value, 1);
      expect(panelIsAccessible(), isTrue);

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(find.text('Panel'), findsOneWidget);
      expect(panelIsAccessible(), isFalse);
      expect(animation.value, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(animation.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('Panel'), findsNothing);
      semantics.dispose();
    });

    testWidgets('mounts before forwarding and supports rapid reversal', (
      tester,
    ) async {
      late Animation<double> animation;
      await tester.pumpMaterialWidget(
        NakedDisclosure(
          child: const Text('Trigger'),
          panel: const Text('Panel'),
          transitionBuilder: (context, value, child) {
            animation = value;
            return FadeTransition(opacity: value, child: child);
          },
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(find.text('Panel'), findsOneWidget);
      expect(animation.value, 0);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Trigger'));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Panel'), findsOneWidget);
      expect(animation.value, 1);
    });

    testWidgets('retains stateful panel identity through close and reversal', (
      tester,
    ) async {
      var initializations = 0;
      var disposals = 0;
      await tester.pumpMaterialWidget(
        NakedDisclosure(
          defaultExpanded: true,
          child: const Text('Trigger'),
          panel: _PanelLifecycleProbe(
            onInitialized: () => initializations++,
            onDisposed: () => disposals++,
          ),
          transitionBuilder: (context, animation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );

      expect(initializations, 1);
      await tester.tap(find.text('Panel 0'));
      await tester.pump();
      expect(find.text('Panel 1'), findsOneWidget);

      await tester.tap(find.text('Trigger'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Panel 1'), findsOneWidget);
      expect(initializations, 1);
      expect(disposals, 0);

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Panel 1'), findsNothing);
      expect(disposals, 1);
    });

    testWidgets('updates animation timing while open', (tester) async {
      var style = const AnimationStyle(
        curve: Curves.linear,
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 400),
      );
      late Animation<double> animation;
      late StateSetter rebuild;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedDisclosure(
              child: const Text('Trigger'),
              panel: const Text('Panel'),
              animationStyle: style,
              transitionBuilder: (context, value, child) {
                animation = value;
                return FadeTransition(opacity: value, child: child);
              },
            );
          },
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(animation.value, closeTo(0.25, 0.05));
      rebuild(
        () => style = const AnimationStyle(
          curve: Curves.linear,
          duration: Duration(milliseconds: 100),
          reverseDuration: Duration(milliseconds: 100),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(animation.value, 1);
    });

    testWidgets('noAnimation and reduced motion snap panel lifecycle', (
      tester,
    ) async {
      await tester.pumpMaterialWidget(
        NakedDisclosure(
          animationStyle: AnimationStyle.noAnimation,
          child: const Text('No animation'),
          panel: const Text('First panel'),
          transitionBuilder: (context, animation, child) => child,
        ),
      );
      await tester.tap(find.text('No animation'));
      await tester.pump();
      expect(find.text('First panel'), findsOneWidget);
      await tester.tap(find.text('No animation'));
      await tester.pump();
      expect(find.text('First panel'), findsNothing);

      await tester.pumpMaterialWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: NakedDisclosure(
            child: const Text('Reduced motion'),
            panel: const Text('Second panel'),
            transitionBuilder: (context, animation, child) => child,
          ),
        ),
      );
      await tester.tap(find.text('Reduced motion'));
      await tester.pump();
      expect(find.text('Second panel'), findsOneWidget);
      await tester.tap(find.text('Reduced motion'));
      await tester.pump();
      expect(find.text('Second panel'), findsNothing);
    });

    testWidgets('can dispose during an active transition', (tester) async {
      var show = true;
      late StateSetter rebuild;
      await tester.pumpMaterialWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return show
                ? NakedDisclosure(
                    child: const Text('Trigger'),
                    panel: const Text('Panel'),
                    transitionBuilder: (context, animation, child) =>
                        FadeTransition(opacity: animation, child: child),
                  )
                : const SizedBox();
          },
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump(const Duration(milliseconds: 50));
      rebuild(() => show = false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

class _PanelLifecycleProbe extends StatefulWidget {
  const _PanelLifecycleProbe({
    required this.onInitialized,
    required this.onDisposed,
  });

  final VoidCallback onInitialized;
  final VoidCallback onDisposed;

  @override
  State<_PanelLifecycleProbe> createState() => _PanelLifecycleProbeState();
}

class _PanelLifecycleProbeState extends State<_PanelLifecycleProbe> {
  var _value = 0;

  @override
  void initState() {
    super.initState();
    widget.onInitialized();
  }

  @override
  void dispose() {
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => _value++),
      child: Text('Panel $_value'),
    );
  }
}
