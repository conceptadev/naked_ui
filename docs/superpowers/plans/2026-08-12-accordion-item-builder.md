# Accordion Item Builder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a backward-compatible `NakedAccordion.itemBuilder` that can decorate the fully wired item from its authoritative state scope, eliminating downstream interaction-state mirroring.

**Architecture:** Derive one `NakedAccordionItemState<T>` and place the trigger, transitioned panel, default column, and optional item wrapper under one `NakedStateScopeBuilder`. Keep the trigger builder and default layout unchanged, but make pointer press state observable without requiring a callback.

**Tech Stack:** Dart 3.9+, Flutter 3.41+, `flutter_test`, Naked UI typed state scopes, Melos.

## Global Constraints

- Keep `NakedAccordion.builder` source-compatible and required.
- Add only one optional public property: `ValueWidgetBuilder<NakedAccordionItemState<T>>? itemBuilder`.
- Preserve default column layout, panel transitions, keyboard behavior, semantics, labels, and `excludeSemantics`.
- Use one authoritative item state scope and controller across the trigger, panel, and item builder.
- Keep expansion-controller min/max behavior unchanged.
- Do not add dependencies or styling to Naked UI.

---

### Task 1: Add the authoritative whole-item composition hook

**Files:**
- Modify: `packages/naked_ui/test/src/naked_accordion_test.dart`
- Modify: `packages/naked_ui/test/semantics/naked_accordion_semantics_test.dart`
- Modify: `packages/naked_ui/lib/src/naked_accordion.dart`

**Interfaces:**
- Consumes: `NakedAccordionItemState<T>`, `NakedStateScopeBuilder<T>`, and `ValueWidgetBuilder<T>`.
- Produces: optional `NakedAccordion<T>.itemBuilder` with signature `ValueWidgetBuilder<NakedAccordionItemState<T>>?`.

- [ ] **Step 1: Write failing widget tests for composition and controller ownership**

Add an `Item Builder` group that supplies an initially expanded accordion. Capture `NakedAccordionItemState.controllerOf<String>(context)` from the trigger builder, panel `Builder`, and `itemBuilder`; wrap the supplied child in a keyed widget; and assert that the wrapper contains both trigger and panel and all three captured controllers are identical.

```dart
testWidgets('wraps the complete item in one authoritative state scope', (
  tester,
) async {
  final controller = NakedAccordionController<String>();
  addTearDown(controller.dispose);
  WidgetStatesController? triggerStates;
  WidgetStatesController? panelStates;
  WidgetStatesController? itemStates;

  await tester.pumpMaterialWidget(
    NakedAccordionGroup<String>(
      controller: controller,
      initialExpandedValues: const ['item'],
      child: NakedAccordion<String>(
        value: 'item',
        builder: (context, state) {
          triggerStates = NakedAccordionItemState.controllerOf<String>(context);
          return const Text('Trigger');
        },
        itemBuilder: (context, state, child) {
          itemStates = NakedAccordionItemState.controllerOf<String>(context);
          return KeyedSubtree(key: const Key('item'), child: child!);
        },
        child: Builder(
          builder: (context) {
            panelStates = NakedAccordionItemState.controllerOf<String>(context);
            return const Text('Panel');
          },
        ),
      ),
    ),
  );

  expect(find.descendant(of: find.byKey(const Key('item')), matching: find.text('Trigger')), findsOneWidget);
  expect(find.descendant(of: find.byKey(const Key('item')), matching: find.text('Panel')), findsOneWidget);
  expect(triggerStates, same(itemStates));
  expect(panelStates, same(itemStates));
});
```

- [ ] **Step 2: Write failing interaction-state tests**

Add tests that capture the latest item snapshot and controller. Verify hover survives disable/re-enable while the mouse remains stationary, disabled state changes in the same controller, pointer press is observable when `onPressChange` is omitted, and tapping/Enter still expands the supplied panel.

```dart
testWidgets('keeps authoritative hover state when disabled in place', (
  tester,
) async {
  var enabled = true;
  late StateSetter rebuild;
  NakedAccordionItemState<String>? latestState;
  WidgetStatesController? itemStates;
  final controller = NakedAccordionController<String>();
  addTearDown(controller.dispose);

  await tester.pumpMaterialWidget(
    StatefulBuilder(
      builder: (context, setState) {
        rebuild = setState;
        return NakedAccordionGroup<String>(
          controller: controller,
          child: NakedAccordion<String>(
            enabled: enabled,
            value: 'item',
            builder: (_, _) => const SizedBox(
              key: Key('trigger'),
              width: 100,
              height: 40,
              child: Text('Trigger'),
            ),
            itemBuilder: (context, state, child) {
              latestState = state;
              itemStates =
                  NakedAccordionItemState.controllerOf<String>(context);
              return child!;
            },
            child: const Text('Panel'),
          ),
        );
      },
    ),
  );

  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer();
  await mouse.moveTo(tester.getCenter(find.byKey(const Key('trigger'))));
  await tester.pump();
  expect(latestState!.isHovered, isTrue);

  rebuild(() => enabled = false);
  await tester.pump();
expect(latestState!.isHovered, isTrue);
expect(latestState!.isDisabled, isTrue);
expect(itemStates!.value, containsAll(<WidgetState>{
  WidgetState.hovered,
  WidgetState.disabled,
}));

  rebuild(() => enabled = true);
  await tester.pump();
  expect(latestState!.isHovered, isTrue);
  expect(latestState!.isDisabled, isFalse);
});

testWidgets('reports pressed state without requiring a callback', (
  tester,
) async {
  NakedAccordionItemState<String>? latestState;
  await tester.pumpMaterialWidget(
    NakedAccordionGroup<String>(
      controller: NakedAccordionController<String>(),
      child: NakedAccordion<String>(
        value: 'item',
        builder: (_, _) => const Text('Trigger'),
        itemBuilder: (_, state, child) {
          latestState = state;
          return child!;
        },
        child: const Text('Panel'),
      ),
    ),
  );

final press = await tester.startGesture(tester.getCenter(find.text('Trigger')));
await tester.pump();
expect(latestState!.isPressed, isTrue);
await press.up();
await tester.pump();
expect(latestState!.isPressed, isFalse);
});
```

- [ ] **Step 3: Write failing compatibility tests**

Verify a keyed `transitionBuilder` remains below the item wrapper and a focused item still toggles when `LogicalKeyboardKey.enter` is sent. Keep the existing no-`itemBuilder` tests as the default-layout regression suite.

```dart
testWidgets('preserves panel transitions and keyboard activation', (
  tester,
) async {
  final controller = NakedAccordionController<String>();
  final focusNode = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focusNode.dispose);

  await tester.pumpMaterialWidget(
    NakedAccordionGroup<String>(
      controller: controller,
      child: NakedAccordion<String>(
        value: 'item',
        focusNode: focusNode,
        builder: (_, _) => const Text('Trigger'),
        transitionBuilder: (panel) => KeyedSubtree(
          key: const Key('transition'),
          child: panel,
        ),
        itemBuilder: (_, _, child) => KeyedSubtree(
          key: const Key('item'),
          child: child!,
        ),
        child: const Text('Panel'),
      ),
    ),
  );

  focusNode.requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();

  expect(find.text('Panel'), findsOneWidget);
  expect(
    find.descendant(
      of: find.byKey(const Key('item')),
      matching: find.byKey(const Key('transition')),
    ),
    findsOneWidget,
  );
});
```

- [ ] **Step 4: Write a failing semantics test**

Wrap an accordion with `itemBuilder` and assert its trigger still exposes the existing button, enabled, expanded, tap, and focus semantics while its expanded panel remains separately accessible.

```dart
testWidgets('itemBuilder preserves disclosure semantics', (tester) async {
  final handle = tester.ensureSemantics();
  addTearDown(handle.dispose);
  await tester.pumpWidget(
    _buildTestApp(
      NakedAccordionGroup<String>(
        controller: NakedAccordionController<String>(),
        initialExpandedValues: const ['item'],
        child: NakedAccordion<String>(
          value: 'item',
          semanticLabel: 'Header',
          builder: (_, _) => const Text('Header'),
          itemBuilder: (_, _, child) => KeyedSubtree(
            key: const Key('item'),
            child: child!,
          ),
          child: const Text('Body'),
        ),
      ),
    ),
  );

  expect(
    tester.getSemantics(find.text('Header')),
    matchesSemantics(
      label: 'Header',
      isButton: true,
      hasEnabledState: true,
      isEnabled: true,
      isFocusable: true,
      hasExpandedState: true,
      isExpanded: true,
      hasTapAction: true,
      hasFocusAction: true,
    ),
  );
  expect(find.text('Body'), findsOneWidget);
});
```

- [ ] **Step 5: Run the focused tests and verify red**

Run:

```bash
fvm flutter test packages/naked_ui/test/src/naked_accordion_test.dart packages/naked_ui/test/semantics/naked_accordion_semantics_test.dart
```

Expected: compilation fails because `itemBuilder` is not yet a named `NakedAccordion` parameter.

- [ ] **Step 6: Implement the minimal public API and shared scope**

Add `this.itemBuilder` to the constructor and document the property:

```dart
/// Builds a presentation wrapper around the fully assembled item.
///
/// The supplied child contains the interactive trigger followed by the
/// transitioned panel. The callback context is below the item state scope.
final ValueWidgetBuilder<NakedAccordionItemState<T>>? itemBuilder;
```

Replace the two item scopes with one scope around the complete composition:

```dart
Widget result = NakedStateScopeBuilder<NakedAccordionItemState<T>>(
  value: accordionState,
  builder: (context, accordionState, child) {
    final Widget trigger = widget.builder(context, accordionState);
    final bool excludeTriggerSemantics =
        widget.excludeSemantics || widget.semanticLabel != null;
    final triggerContent = GestureDetector(
      onTapDown: widget.enabled
          ? (_) => updatePressState(true, widget.onPressChange)
          : null,
      onTapUp: widget.enabled
          ? (_) => updatePressState(false, widget.onPressChange)
          : null,
      onTap: widget.enabled ? onTap : null,
      onTapCancel: widget.enabled
          ? () => updatePressState(false, widget.onPressChange)
          : null,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      child: excludeTriggerSemantics
          ? ExcludeSemantics(child: trigger)
          : trigger,
    );
    final accordionChild = widget.excludeSemantics
        ? triggerContent
        : Semantics(
            enabled: widget.enabled,
            button: true,
            expanded: isExpanded,
            label: widget.semanticLabel,
            onTap: widget.enabled ? onTap : null,
            child: triggerContent,
          );
    final focusableTrigger = NakedFocusableDetector(
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      onFocusChange: (focused) =>
          updateFocusState(focused, widget.onFocusChange),
      onHoverChange: (hovered) =>
          updateHoverState(hovered, widget.onHoverChange),
      focusNode: widget.focusNode,
      mouseCursor: widget.enabled
          ? widget.mouseCursor
          : SystemMouseCursors.basic,
      shortcuts: NakedIntentActions.accordion.shortcuts,
      actions: NakedIntentActions.accordion.actions(onToggle: onTap),
      child: accordionChild,
    );
    final transitionedPanel = widget.transitionBuilder?.call(panel) ?? panel;
    final item = Column(
      mainAxisSize: MainAxisSize.min,
      children: [focusableTrigger, transitionedPanel],
    );
    return widget.itemBuilder?.call(context, accordionState, item) ?? item;
  },
);
return widget.excludeSemantics ? ExcludeSemantics(child: result) : result;
```

Enable `onTapDown`, `onTapUp`, and `onTapCancel` whenever the accordion is enabled, and pass the nullable callback to `updatePressState`. Clear pressed state if the widget becomes disabled.

- [ ] **Step 7: Run the focused tests and verify green**

Run the command from Step 5. Expected: all accordion widget and semantics tests pass.

- [ ] **Step 8: Refactor only while green**

Remove duplicated state scopes and retain local names that distinguish the raw trigger, wired trigger, transitioned panel, assembled item, and optional wrapper. Run the focused command after each cleanup.

- [ ] **Step 9: Commit the tested API**

```bash
git add packages/naked_ui/lib/src/naked_accordion.dart packages/naked_ui/test/src/naked_accordion_test.dart packages/naked_ui/test/semantics/naked_accordion_semantics_test.dart
git commit -m "feat(accordion): add whole-item builder"
```

### Task 2: Document downstream-safe use

**Files:**
- Modify: `docs/widget/accordion.mdx`
- Modify: `packages/naked_ui/CHANGELOG.md`

**Interfaces:**
- Consumes: `NakedAccordion.itemBuilder` from Task 1.
- Produces: public guidance for resolving `NakedAccordionItemState.controllerOf<String>(context)` without mirroring state.

- [ ] **Step 1: Add the item builder to the API documentation**

Update the constructor reference and property list, then add a concise example:

```dart
itemBuilder: (context, state, child) {
  final states = NakedAccordionItemState.controllerOf<String>(context);
  return ListenableBuilder(
    listenable: states,
    builder: (context, _) => DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: states.value.contains(WidgetState.focused)
              ? Colors.blue
              : Colors.grey,
        ),
      ),
      child: child,
    ),
  );
},
```

Explain that the supplied child retains Naked UI's trigger behavior, transition, panel, and semantics, and should be kept in the returned subtree.

- [ ] **Step 2: Check documentation formatting and links**

Add a `### Features` entry under `1.0.0-beta.9` stating that
`NakedAccordion.itemBuilder` decorates the fully assembled item from one
authoritative item state scope and that pressed state is observable without an
`onPressChange` callback.

Run `git diff --check` and inspect `git diff -- docs/widget/accordion.mdx`. Expected: no whitespace errors and all referenced APIs match Task 1.

- [ ] **Step 3: Commit documentation**

```bash
git add docs/widget/accordion.mdx packages/naked_ui/CHANGELOG.md
git commit -m "docs(accordion): explain whole-item styling"
```

### Task 3: Review, verify, and publish

**Files:**
- Review all files changed from `origin/main`.

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: a review-ready GitHub pull request targeting `main`.

- [ ] **Step 1: Simplify and review the diff**

Inspect `git diff origin/main...HEAD` for unnecessary API surface, duplicated composition, callback-dependent state, semantic-tree changes, hidden layout changes, missing docs, and untested assumptions. Apply only behavior-preserving simplifications, then rerun focused tests.

- [ ] **Step 2: Run repository verification**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test packages/naked_ui/test
fvm flutter test packages/example/test
```

Expected: every command exits zero. Also run `git diff --check` and confirm the worktree is clean after committing any review corrections.

- [ ] **Step 3: Push and open the PR**

Push `feat/accordion-item-builder` and create a PR targeting `main`. The description must include the Remix disable-while-hovered desynchronization case, explain why authoritative scope composition fixes it, state compatibility boundaries, list tests, and identify downstream Remix adoption as a separate follow-up.
