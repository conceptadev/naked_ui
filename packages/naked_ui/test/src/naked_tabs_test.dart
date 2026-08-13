// File: naked_tabs_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'helpers/builder_state_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  PageRoute<T> _defaultPageRouteBuilder<T>(
    RouteSettings settings,
    WidgetBuilder builder,
  ) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    );
  }

  Widget _harness({
    required String initialSelected,
    bool groupEnabled = true,
    bool tab1Enabled = true,
    bool tab2Enabled = true,
    bool maintainState = true,
    NakedTabActivationMode activationMode = NakedTabActivationMode.automatic,
    ValueChanged<String>? onChangedSpy,
    VoidCallback? onEscapeSpy,
    Key? tab1Key,
    Key? tab2Key,
    Key? view1Key,
    Key? view2Key,
    ValueChanged<NakedTabState>? tab1StatesSpy,
  }) {
    // Keep selection across rebuilds using a closure variable updated via StatefulBuilder.setState.
    String selected = initialSelected;
    return WidgetsApp(
      color: const Color(0xFF000000),
      // Provide a pass-through builder to satisfy WidgetsApp requirements.
      builder: (context, child) => child ?? const SizedBox.shrink(),
      // Provide a simple page route builder since `home` is set.
      pageRouteBuilder: _defaultPageRouteBuilder,
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            void handleChanged(String id) {
              onChangedSpy?.call(id);
              selected = id;
              setState(() {});
            }

            return NakedTabs(
              selectedTabId: selected,
              enabled: groupEnabled,
              onChanged: handleChanged,
              activationMode: activationMode,
              onEscapePressed: onEscapeSpy,
              child: Column(
                children: [
                  NakedTabBar(
                    child: Row(
                      children: [
                        NakedTab(
                          tabId: 'tab1',
                          enabled: tab1Enabled,
                          semanticLabel: 'Tab 1',
                          onFocusChange: (_) {},
                          builder: tab1StatesSpy == null
                              ? null
                              : (ctx, tabState, child) {
                                  tab1StatesSpy(tabState);
                                  return child ?? const SizedBox.shrink();
                                },
                          child: SizedBox(
                            key: tab1Key ?? const Key('tab1'),
                            width: 100,
                            height: 40,
                            child: const Center(child: Text('One')),
                          ),
                        ),
                        NakedTab(
                          tabId: 'tab2',
                          enabled: tab2Enabled,
                          semanticLabel: 'Tab 2',
                          child: SizedBox(
                            key: tab2Key ?? const Key('tab2'),
                            width: 100,
                            height: 40,
                            child: const Center(child: Text('Two')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  NakedTabView(
                    tabId: 'tab1',
                    maintainState: maintainState,
                    child: SizedBox(
                      key: view1Key ?? const Key('view1'),
                      height: 10,
                      width: 10,
                    ),
                  ),
                  NakedTabView(
                    tabId: 'tab2',
                    maintainState: maintainState,
                    child: SizedBox(
                      key: view2Key ?? const Key('view2'),
                      height: 10,
                      width: 10,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets(
    'Controlled host that commits asynchronously receives one onChanged '
    'per press',
    (tester) async {
      // Regression: focusing a tab selects it (selection follows focus) and
      // the tap that caused the focus selects it again. A host that does not
      // rebuild synchronously inside onChanged must still see one call.
      final changes = <String>[];
      final tab2 = UniqueKey();

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, child) => child ?? const SizedBox.shrink(),
          pageRouteBuilder: _defaultPageRouteBuilder,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: NakedTabs(
              // Never rebuilt with a new selection: models a host that commits
              // asynchronously (or rejects the change).
              selectedTabId: 'tab1',
              onChanged: changes.add,
              child: Column(
                children: [
                  NakedTabBar(
                    child: Row(
                      children: [
                        const NakedTab(tabId: 'tab1', child: Text('Tab 1')),
                        NakedTab(
                          key: tab2,
                          tabId: 'tab2',
                          child: const Text('Tab 2'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(tab2));
      await tester.pumpAndSettle();

      expect(changes, ['tab2']);

      // A later user press is a new request, even if the controlled host has
      // not committed the earlier selection.
      await tester.tap(find.byKey(tab2));
      await tester.pumpAndSettle();

      expect(changes, ['tab2', 'tab2']);
    },
  );

  testWidgets(
    'Keyboard activation on a rejecting host fires onChanged every press',
    (tester) async {
      // Regression: a frame-scoped dedup guard is only cleared when a frame
      // is produced, and a host that rejects the change marks nothing dirty —
      // no frame separates two real key presses, so the second press was
      // swallowed. Deliberately no pump between the two activations below;
      // pumping would manufacture a frame that production never gets.
      final changes = <String>[];
      final tab1 = UniqueKey();
      final tab2 = UniqueKey();

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, child) => child ?? const SizedBox.shrink(),
          pageRouteBuilder: _defaultPageRouteBuilder,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: NakedTabs(
              // Never rebuilt with a new selection: models a host that
              // rejects every requested change.
              selectedTabId: 'tab1',
              onChanged: changes.add,
              child: Column(
                children: [
                  NakedTabBar(
                    child: Row(
                      children: [
                        NakedTab(
                          key: tab1,
                          tabId: 'tab1',
                          child: const Text('Tab 1'),
                        ),
                        NakedTab(
                          key: tab2,
                          tabId: 'tab2',
                          child: const Text('Tab 2'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus tab1 (selecting the already-selected tab is a no-op), then
      // traverse to tab2: selection follows focus and fires once.
      await tester.tap(find.byKey(tab1));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(changes, ['tab2']);

      // Each activation is a new request, with no frame between them.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(changes, ['tab2', 'tab2', 'tab2']);
    },
  );

  testWidgets('Selection follows focus via arrow keys', (tester) async {
    final changes = <String>[];
    final tab1 = UniqueKey();
    final tab2 = UniqueKey();

    await tester.pumpWidget(
      _harness(
        initialSelected: 'tab1',
        onChangedSpy: changes.add,
        tab1Key: tab1,
        tab2Key: tab2,
      ),
    );
    await tester.pumpAndSettle();

    // Focus tab1 by tapping.
    await tester.tap(find.byKey(tab1));
    await tester.pump();

    // Move focus right: default shortcuts map Right Arrow to directional focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // Selection should follow focus (tab2).
    expect(changes.last, 'tab2');
  });

  testWidgets('manual activation moves focus without selecting', (
    tester,
  ) async {
    final changes = <String>[];
    final tab1 = UniqueKey();
    final tab2 = UniqueKey();

    await tester.pumpWidget(
      _harness(
        initialSelected: 'tab1',
        activationMode: NakedTabActivationMode.manual,
        onChangedSpy: changes.add,
        tab1Key: tab1,
        tab2Key: tab2,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(tab1));
    await tester.pump();
    changes.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(changes, isEmpty);
    expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(changes, ['tab2']);
  });

  testWidgets('controller changes rebuild tabs and panels', (tester) async {
    final controller = NakedTabController(selectedTabId: 'tab1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, child) => child ?? const SizedBox.shrink(),
        pageRouteBuilder: _defaultPageRouteBuilder,
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: NakedTabs(
            controller: controller,
            child: Column(
              children: [
                NakedTabBar(
                  child: Row(
                    children: [
                      NakedTab(
                        tabId: 'tab1',
                        builder: (_, state, __) =>
                            Text(state.isSelected ? 'Tab 1 selected' : 'Tab 1'),
                      ),
                      NakedTab(
                        tabId: 'tab2',
                        builder: (_, state, __) =>
                            Text(state.isSelected ? 'Tab 2 selected' : 'Tab 2'),
                      ),
                    ],
                  ),
                ),
                const NakedTabView(tabId: 'tab1', child: Text('Panel 1')),
                const NakedTabView(tabId: 'tab2', child: Text('Panel 2')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tab 1 selected'), findsOneWidget);
    expect(find.text('Panel 1'), findsOneWidget);
    expect(find.text('Panel 2'), findsNothing);

    controller.selectTab('tab2');
    await tester.pump();

    expect(find.text('Tab 2 selected'), findsOneWidget);
    expect(find.text('Panel 1'), findsNothing);
    expect(find.text('Panel 2'), findsOneWidget);
  });

  testWidgets('tabs invoke the latest parent callback', (tester) async {
    var useSecondCallback = false;
    var firstCalls = 0;
    var secondCalls = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, child) => child ?? const SizedBox.shrink(),
        pageRouteBuilder: _defaultPageRouteBuilder,
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedTabs(
                selectedTabId: 'tab1',
                onChanged: useSecondCallback
                    ? (_) => secondCalls++
                    : (_) => firstCalls++,
                child: const NakedTabBar(
                  child: Row(
                    children: [
                      NakedTab(tabId: 'tab1', child: Text('First')),
                      NakedTab(tabId: 'tab2', child: Text('Second')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    rebuild(() => useSecondCallback = true);
    await tester.pump();
    await tester.tap(find.text('Second'));
    await tester.pump();

    expect(firstCalls, 0);
    expect(secondCalls, 1);
  });

  testWidgets('Enter/Space activation also selects (redundant but fine)', (
    tester,
  ) async {
    final changes = <String>[];
    final tab1 = UniqueKey();
    await tester.pumpWidget(
      _harness(
        initialSelected: 'tab2',
        onChangedSpy: changes.add,
        tab1Key: tab1,
      ),
    );
    await tester.pumpAndSettle();

    // Focus tab1.
    await tester.tap(find.byKey(tab1));
    await tester.pump();

    // Press Space.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    // The tap selected 'tab1' exactly once; Space re-activates the
    // already-selected tab, which is a no-op. An exact list guards against
    // a future double-fire.
    expect(changes, ['tab1']);
  });

  testWidgets('Disabled group: selection does not change on focus or tap', (
    tester,
  ) async {
    final changes = <String>[];
    final tab2 = UniqueKey();

    await tester.pumpWidget(
      _harness(
        initialSelected: 'tab1',
        groupEnabled: false, // group disabled => _effectiveEnabled false
        onChangedSpy: changes.add,
        tab2Key: tab2,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(tab2));
    await tester.pump();

    expect(
      changes,
      isEmpty,
      reason: 'Disabled group should ignore selection changes',
    );
  });

  testWidgets('Disabled tab: not focusable, not traversable', (tester) async {
    final changes = <String>[];
    final tab1 = UniqueKey();
    final tab2 = UniqueKey();

    await tester.pumpWidget(
      _harness(
        initialSelected: 'tab1',
        tab2Enabled: false,
        onChangedSpy: changes.add,
        tab1Key: tab1,
        tab2Key: tab2,
      ),
    );
    await tester.pumpAndSettle();

    // Focus tab1.
    await tester.tap(find.byKey(tab1));
    await tester.pump();

    // Try to move focus right; tab2 is disabled and skipped.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // Selection should remain tab1 (no change fired).
    expect(changes.isEmpty || changes.last == 'tab1', isTrue);
  });

  testWidgets('disabled tab stays unfocusable after focus-node replacement', (
    tester,
  ) async {
    final firstNode = FocusNode(debugLabel: 'first disabled node');
    final replacementNode = FocusNode(debugLabel: 'replacement disabled node');
    addTearDown(firstNode.dispose);
    addTearDown(replacementNode.dispose);
    var node = firstNode;
    late StateSetter rebuild;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(
            navigationMode: NavigationMode.directional,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedTabs(
                selectedTabId: 'tab',
                onChanged: (_) {},
                child: NakedTabBar(
                  child: NakedTab(
                    tabId: 'tab',
                    enabled: false,
                    focusNode: node,
                    child: const SizedBox(width: 40, height: 40),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    rebuild(() => node = replacementNode);
    await tester.pump();
    replacementNode.requestFocus();
    await tester.pump();

    expect(replacementNode.hasFocus, isFalse);
    expect(replacementNode.skipTraversal, isTrue);
  });

  testWidgets('Panels show/hide; maintainState=false removes inactive view', (
    tester,
  ) async {
    final changes = <String>[];
    final tab2 = UniqueKey();
    final view1 = UniqueKey();
    final view2 = UniqueKey();

    await tester.pumpWidget(
      _harness(
        initialSelected: 'tab1',
        maintainState: false,
        onChangedSpy: changes.add,
        tab2Key: tab2,
        view1Key: view1,
        view2Key: view2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(view1), findsOneWidget);
    expect(find.byKey(view2), findsNothing);

    // Focus tab2 -> selects tab2; view2 becomes visible; view1 removed.
    await tester.tap(find.byKey(tab2));
    await tester.pump();

    expect(find.byKey(view2), findsOneWidget);
    expect(find.byKey(view1), findsNothing);
  });

  testWidgets('Hover and pressed states surface through builder', (
    tester,
  ) async {
    final statesLog = <Set<WidgetState>>[];
    final tab1 = UniqueKey();

    await tester.pumpWidget(
      _harness(
        initialSelected: 'tab1',
        tab1Key: tab1,
        tab1StatesSpy: (state) => statesLog.add(state.states.toSet()),
      ),
    );
    await tester.pumpAndSettle();

    // Start mouse hover using a direct gesture for determinism within this suite.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.byKey(tab1)));
    await tester.pumpAndSettle();
    final sawHover = statesLog.any((s) => s.contains(WidgetState.hovered));
    expect(sawHover, isTrue);

    // Press and release to toggle pressed state.
    await tester.press(find.byKey(tab1)); // down+up with a short delay
    await tester.pump();

    // We should see pressed true at some point; because the builder updates on press transitions,
    // at least one snapshot must include WidgetState.pressed.
    final sawPressed = statesLog.any((s) => s.contains(WidgetState.pressed));
    expect(sawPressed, isTrue);

    await gesture.removePointer();
  });

  testWidgets('ESC triggers onEscapePressed at group level', (tester) async {
    bool esc = false;
    final tab1 = UniqueKey();

    await tester.pumpWidget(
      _harness(
        initialSelected: 'tab1',
        onEscapeSpy: () => esc = true,
        tab1Key: tab1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(tab1));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(esc, isTrue);
  });

  group('Builder Tests', () {
    testStateScopeBuilder<NakedTabState>(
      'builder\'s context contains NakedStateScope',
      (builder) => NakedTabs(
        selectedTabId: 'tab1',
        onChanged: (value) {},
        child: NakedTabBar(
          child: Row(
            children: [
              NakedTab(
                tabId: 'tab1',
                builder: (context, state, child) => SizedBox(
                  width: 1,
                  height: 1,
                  child: builder(context, state, child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  });

  group('Home/End keyboard navigation', () {
    Widget threeTabHarness({
      required String initialSelected,
      Axis orientation = Axis.horizontal,
      ValueChanged<String>? onChangedSpy,
      Key? tab1Key,
      Key? tab2Key,
      Key? tab3Key,
    }) {
      String selected = initialSelected;
      return WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, child) => child ?? const SizedBox.shrink(),
        pageRouteBuilder: _defaultPageRouteBuilder,
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              void handleChanged(String id) {
                onChangedSpy?.call(id);
                selected = id;
                setState(() {});
              }

              return NakedTabs(
                selectedTabId: selected,
                onChanged: handleChanged,
                orientation: orientation,
                child: Column(
                  children: [
                    NakedTabBar(
                      child: Flex(
                        direction: orientation,
                        children: [
                          NakedTab(
                            tabId: 'tab1',
                            child: SizedBox(
                              key: tab1Key ?? const Key('tab1'),
                              width: 100,
                              height: 40,
                              child: const Center(child: Text('One')),
                            ),
                          ),
                          NakedTab(
                            tabId: 'tab2',
                            child: SizedBox(
                              key: tab2Key ?? const Key('tab2'),
                              width: 100,
                              height: 40,
                              child: const Center(child: Text('Two')),
                            ),
                          ),
                          NakedTab(
                            tabId: 'tab3',
                            child: SizedBox(
                              key: tab3Key ?? const Key('tab3'),
                              width: 100,
                              height: 40,
                              child: const Center(child: Text('Three')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('Home key focuses first tab', (tester) async {
      final changes = <String>[];
      final tab1 = UniqueKey();
      final tab2 = UniqueKey();
      final tab3 = UniqueKey();

      await tester.pumpWidget(
        threeTabHarness(
          initialSelected: 'tab2',
          onChangedSpy: changes.add,
          tab1Key: tab1,
          tab2Key: tab2,
          tab3Key: tab3,
        ),
      );
      await tester.pumpAndSettle();

      // Focus tab3 by tapping.
      await tester.tap(find.byKey(tab3));
      await tester.pump();
      changes.clear();

      // Press Home to focus first tab.
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();

      expect(changes.last, 'tab1');
    });

    testWidgets('End key focuses last tab', (tester) async {
      final changes = <String>[];
      final tab1 = UniqueKey();
      final tab2 = UniqueKey();
      final tab3 = UniqueKey();

      await tester.pumpWidget(
        threeTabHarness(
          initialSelected: 'tab1',
          onChangedSpy: changes.add,
          tab1Key: tab1,
          tab2Key: tab2,
          tab3Key: tab3,
        ),
      );
      await tester.pumpAndSettle();

      // Focus tab1 by tapping.
      await tester.tap(find.byKey(tab1));
      await tester.pump();
      changes.clear();

      // Press End to focus last tab.
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();

      expect(changes.last, 'tab3');
    });

    testWidgets('Home and End follow vertical tab orientation', (tester) async {
      final changes = <String>[];
      final tab2 = UniqueKey();

      await tester.pumpWidget(
        threeTabHarness(
          initialSelected: 'tab2',
          orientation: Axis.vertical,
          onChangedSpy: changes.add,
          tab2Key: tab2,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(tab2));
      await tester.pump();
      changes.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(changes.last, 'tab1');

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(changes.last, 'tab3');
    });

    testWidgets('Home and End stay within the tab bar', (tester) async {
      final before = FocusNode(debugLabel: 'before tabs');
      final first = FocusNode(debugLabel: 'first tab');
      final middle = FocusNode(debugLabel: 'middle tab');
      final last = FocusNode(debugLabel: 'last tab');
      final after = FocusNode(debugLabel: 'after tabs');
      addTearDown(before.dispose);
      addTearDown(first.dispose);
      addTearDown(middle.dispose);
      addTearDown(last.dispose);
      addTearDown(after.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Focus(
                focusNode: before,
                child: const SizedBox(width: 40, height: 40),
              ),
              NakedTabs(
                selectedTabId: 'middle',
                onChanged: (_) {},
                child: NakedTabBar(
                  child: Row(
                    children: [
                      NakedTab(
                        tabId: 'first',
                        focusNode: first,
                        child: const SizedBox(width: 40, height: 40),
                      ),
                      NakedTab(
                        tabId: 'middle',
                        focusNode: middle,
                        child: const SizedBox(width: 40, height: 40),
                      ),
                      NakedTab(
                        tabId: 'last',
                        focusNode: last,
                        child: const SizedBox(width: 40, height: 40),
                      ),
                    ],
                  ),
                ),
              ),
              Focus(
                focusNode: after,
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        ),
      );

      middle.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(first.hasPrimaryFocus, isTrue);
      expect(before.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(last.hasPrimaryFocus, isTrue);
      expect(after.hasFocus, isFalse);
    });
  });

  group('Focus iteration limits', () {
    testWidgets('Home/End keys on single tab complete without infinite loop', (
      tester,
    ) async {
      String selected = 'tab1';
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, child) => child ?? const SizedBox.shrink(),
          pageRouteBuilder: _defaultPageRouteBuilder,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setState) {
                return NakedTabs(
                  selectedTabId: selected,
                  onChanged: (id) {
                    selected = id;
                    setState(() {});
                  },
                  child: NakedTabBar(
                    child: Row(
                      children: [
                        NakedTab(
                          tabId: 'tab1',
                          child: const SizedBox(
                            key: Key('tab1'),
                            width: 100,
                            height: 40,
                            child: Center(child: Text('One')),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the single tab.
      await tester.tap(find.byKey(const Key('tab1')));
      await tester.pump();

      // Press Home - should complete without hanging.
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();

      // Press End - should complete without hanging.
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();

      // If we get here, the test passed (no infinite loop).
      expect(selected, 'tab1');
    });
  });

  group('Directional focus with orientation', () {
    Widget orientedHarness({
      required String initialSelected,
      required Axis orientation,
      ValueChanged<String>? onChangedSpy,
      Key? tab1Key,
      Key? tab2Key,
    }) {
      String selected = initialSelected;
      return WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, child) => child ?? const SizedBox.shrink(),
        pageRouteBuilder: _defaultPageRouteBuilder,
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              void handleChanged(String id) {
                onChangedSpy?.call(id);
                selected = id;
                setState(() {});
              }

              return NakedTabs(
                selectedTabId: selected,
                onChanged: handleChanged,
                orientation: orientation,
                child: NakedTabBar(
                  child: orientation == Axis.horizontal
                      ? Row(
                          children: [
                            NakedTab(
                              tabId: 'tab1',
                              child: SizedBox(
                                key: tab1Key ?? const Key('tab1'),
                                width: 100,
                                height: 40,
                                child: const Center(child: Text('One')),
                              ),
                            ),
                            NakedTab(
                              tabId: 'tab2',
                              child: SizedBox(
                                key: tab2Key ?? const Key('tab2'),
                                width: 100,
                                height: 40,
                                child: const Center(child: Text('Two')),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            NakedTab(
                              tabId: 'tab1',
                              child: SizedBox(
                                key: tab1Key ?? const Key('tab1'),
                                width: 100,
                                height: 40,
                                child: const Center(child: Text('One')),
                              ),
                            ),
                            NakedTab(
                              tabId: 'tab2',
                              child: SizedBox(
                                key: tab2Key ?? const Key('tab2'),
                                width: 100,
                                height: 40,
                                child: const Center(child: Text('Two')),
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('horizontal tabs respond to Left/Right arrows', (tester) async {
      final changes = <String>[];
      final tab1 = UniqueKey();
      final tab2 = UniqueKey();

      await tester.pumpWidget(
        orientedHarness(
          initialSelected: 'tab1',
          orientation: Axis.horizontal,
          onChangedSpy: changes.add,
          tab1Key: tab1,
          tab2Key: tab2,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(tab1));
      await tester.pump();
      changes.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(changes.last, 'tab2');
    });

    testWidgets('horizontal tabs ignore Up/Down arrows', (tester) async {
      final changes = <String>[];
      final tab1 = UniqueKey();
      final tab2 = UniqueKey();

      await tester.pumpWidget(
        orientedHarness(
          initialSelected: 'tab1',
          orientation: Axis.horizontal,
          onChangedSpy: changes.add,
          tab1Key: tab1,
          tab2Key: tab2,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(tab1));
      await tester.pump();
      changes.clear();

      // Up/Down should not change selection in horizontal mode.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(changes, isEmpty);
    });

    testWidgets('vertical tabs respond to Up/Down arrows', (tester) async {
      final changes = <String>[];
      final tab1 = UniqueKey();
      final tab2 = UniqueKey();

      await tester.pumpWidget(
        orientedHarness(
          initialSelected: 'tab1',
          orientation: Axis.vertical,
          onChangedSpy: changes.add,
          tab1Key: tab1,
          tab2Key: tab2,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(tab1));
      await tester.pump();
      changes.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(changes.last, 'tab2');
    });

    testWidgets('vertical tabs ignore Left/Right arrows', (tester) async {
      final changes = <String>[];
      final tab1 = UniqueKey();
      final tab2 = UniqueKey();

      await tester.pumpWidget(
        orientedHarness(
          initialSelected: 'tab1',
          orientation: Axis.vertical,
          onChangedSpy: changes.add,
          tab1Key: tab1,
          tab2Key: tab2,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(tab1));
      await tester.pump();
      changes.clear();

      // Left/Right should not change selection in vertical mode.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(changes, isEmpty);
    });
  });

  group('Controller state management', () {
    testWidgets('one press produces one controller notification', (
      tester,
    ) async {
      final controller = NakedTabController(selectedTabId: 'tab1');
      addTearDown(controller.dispose);
      var notifications = 0;
      final tab2Key = UniqueKey();
      controller.addListener(() => notifications++);

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, child) => child ?? const SizedBox.shrink(),
          pageRouteBuilder: _defaultPageRouteBuilder,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: NakedTabs(
              controller: controller,
              child: NakedTabBar(
                child: Row(
                  children: [
                    const NakedTab(
                      tabId: 'tab1',
                      child: SizedBox(width: 100, height: 40),
                    ),
                    NakedTab(
                      key: tab2Key,
                      tabId: 'tab2',
                      child: const SizedBox(width: 100, height: 40),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(tab2Key));
      await tester.pumpAndSettle();

      expect(notifications, 1);
      expect(controller.selectedTabId, 'tab2');
    });

    testWidgets('previousTabId is set when switching tabs', (tester) async {
      final controller = NakedTabController(selectedTabId: 'tab1');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, child) => child ?? const SizedBox.shrink(),
          pageRouteBuilder: _defaultPageRouteBuilder,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: NakedTabs(
              controller: controller,
              child: NakedTabBar(
                child: Row(
                  children: [
                    NakedTab(
                      tabId: 'tab1',
                      child: const SizedBox(
                        key: Key('tab1'),
                        width: 100,
                        height: 40,
                      ),
                    ),
                    NakedTab(
                      tabId: 'tab2',
                      child: const SizedBox(
                        key: Key('tab2'),
                        width: 100,
                        height: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.previousTabId, isNull);

      // Select tab2.
      controller.selectTab('tab2');
      await tester.pump();

      expect(controller.selectedTabId, 'tab2');
      expect(controller.previousTabId, 'tab1');
    });

    testWidgets('selectPrevious returns to previous tab', (tester) async {
      final controller = NakedTabController(selectedTabId: 'tab1');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, child) => child ?? const SizedBox.shrink(),
          pageRouteBuilder: _defaultPageRouteBuilder,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: NakedTabs(
              controller: controller,
              child: NakedTabBar(
                child: Row(
                  children: [
                    NakedTab(
                      tabId: 'tab1',
                      child: const SizedBox(
                        key: Key('tab1'),
                        width: 100,
                        height: 40,
                      ),
                    ),
                    NakedTab(
                      tabId: 'tab2',
                      child: const SizedBox(
                        key: Key('tab2'),
                        width: 100,
                        height: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select tab2.
      controller.selectTab('tab2');
      await tester.pump();
      expect(controller.selectedTabId, 'tab2');

      // Go back to previous.
      controller.selectPrevious();
      expect(controller.selectedTabId, 'tab1');
    });

    testWidgets('one press produces exactly one controller notification', (
      tester,
    ) async {
      final controller = NakedTabController(selectedTabId: 'tab1');
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, child) => child ?? const SizedBox.shrink(),
          pageRouteBuilder: _defaultPageRouteBuilder,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: NakedTabs(
              controller: controller,
              child: NakedTabBar(
                child: Row(
                  children: [
                    NakedTab(
                      tabId: 'tab1',
                      child: const SizedBox(
                        key: Key('tab1'),
                        width: 100,
                        height: 40,
                      ),
                    ),
                    NakedTab(
                      tabId: 'tab2',
                      child: const SizedBox(
                        key: Key('tab2'),
                        width: 100,
                        height: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Settle past the tap's focus follow-up: the press must notify once,
      // not once from the tap and again when focus lands.
      await tester.tapAt(tester.getCenter(find.byKey(const Key('tab2'))));
      await tester.pumpAndSettle();

      expect(notifications, 1);
      expect(controller.selectedTabId, 'tab2');
    });

    testWidgets('selectPrevious does nothing when no previous tab', (
      tester,
    ) async {
      final controller = NakedTabController(selectedTabId: 'tab1');

      // Call selectPrevious without ever switching tabs.
      controller.selectPrevious();

      // Should remain on tab1.
      expect(controller.selectedTabId, 'tab1');
      expect(controller.previousTabId, isNull);
    });
  });
}
