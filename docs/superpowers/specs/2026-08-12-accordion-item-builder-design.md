# Accordion item builder design

## Context

`NakedAccordion.builder` builds only the interactive trigger. The trigger and
panel are currently placed under separate `NakedStateScope` instances, while
the complete item is assembled outside both scopes.

That boundary prevents a design-system adapter from styling the complete item
from the accordion's authoritative interaction state. Remix currently has to
mirror hover, focus, press, disabled, and expanded state above
`NakedAccordion`. The mirrored state can diverge from Naked UI state; for
example, disabling an item while its pointer remains over the trigger clears
the adapter's hover state while Naked UI retains hover state until the pointer
exits.

## Goal

Allow consumers to decorate the fully assembled accordion item using the same
authoritative `NakedAccordionItemState` and `WidgetStatesController` as the
trigger and panel, without changing existing accordion behavior.

## Public API

Add one optional property to `NakedAccordion<T>`:

```dart
final ValueWidgetBuilder<NakedAccordionItemState<T>>? itemBuilder;
```

The callback receives:

- a `BuildContext` below the item state scope;
- the current `NakedAccordionItemState<T>` snapshot; and
- a non-null child containing the fully wired trigger followed by the
  transitioned panel.

The callback follows the existing `(context, state, child)` builder convention
used across Naked UI. Consumers that need a listenable for state-based styling
can resolve the authoritative controller with
`NakedAccordionItemState.controllerOf(context)`.

When `itemBuilder` is omitted, `NakedAccordion` returns the assembled child
unchanged, preserving its current `Column(mainAxisSize: MainAxisSize.min)`
layout.

## Internal composition

`NakedAccordion` will derive one `NakedAccordionItemState<T>` per build and
provide it through one `NakedStateScopeBuilder` around the complete item.
Inside that scope it will:

1. invoke the existing trigger `builder`;
2. preserve the existing gesture, focus, shortcut, action, and trigger
   semantics wrappers;
3. update pressed state whenever the enabled trigger receives pointer press
   events, while continuing to invoke `onPressChange` only when supplied;
4. apply `transitionBuilder` to the expanded or collapsed panel;
5. assemble trigger and panel in the existing column; and
6. pass that assembled widget to `itemBuilder`, when supplied.

The trigger builder, panel subtree, and item builder therefore share one item
state scope and one `WidgetStatesController`. The group expansion controller
and its min/max behavior remain unchanged.

## Accessibility and interaction behavior

The new builder is presentational only. Naked UI continues to own:

- pointer hover and press tracking;
- focus and autofocus behavior;
- Space/Enter activation and focus traversal;
- disclosure button semantics and expanded state;
- disabled behavior and cursor selection;
- panel visibility and transition application; and
- `semanticLabel` and `excludeSemantics` behavior.

The consumer-provided item wrapper must not replace the supplied child if it
wants to retain those behaviors.

## Compatibility

The change is source-compatible because `itemBuilder` is optional. Existing
call sites, widget structure, semantics, transitions, and default layout stay
unchanged. The existing trigger `builder` retains its signature.

The current trigger only tracks pointer press state when `onPressChange` is
non-null. That makes `state.isPressed` callback-dependent, unlike the other
Naked UI builders. Tracking it unconditionally when enabled is an intentional
state-fidelity correction; callback invocation remains optional and existing
gesture activation behavior does not change.

This design intentionally does not expose trigger and panel as separate
arguments. The motivating use case needs an outer state-aware shell, and a
four-argument layout callback would broaden the public API without evidence
that consumers need to reorder or interleave the two children.

It also does not expose a controller callback or add state-change callbacks.
Those alternatives would encourage duplicated mutable state instead of making
the existing authoritative scope composable.

## Tests

The implementation will be developed test-first and will cover:

- `itemBuilder` receiving the fully assembled trigger and expanded panel;
- the trigger builder, panel, and item builder resolving the same item state
  controller;
- the item builder observing authoritative hover, focus, press, disabled, and
  expanded state, including disabling while the pointer remains over the
  trigger;
- unchanged behavior when `itemBuilder` is omitted;
- preserved custom panel transitions;
- preserved Space/Enter activation; and
- preserved disclosure semantics, including disabled and expanded states.

Focused accordion tests will run first, followed by formatting, static
analysis, the package test suite, and the repository's CI-equivalent checks.

## Documentation and downstream adoption

The accordion documentation will describe `itemBuilder` as the hook for
styling the complete item and show controller access from its context. The PR
will include the Remix state-mirroring failure as its motivating downstream
case.

Remix adoption is deliberately outside this upstream PR. After a Naked UI
release contains this API, Remix can remove its private mirrored
`WidgetStatesController` and resolve item container styles directly from the
controller supplied by `NakedAccordionItemState.controllerOf(context)`.
