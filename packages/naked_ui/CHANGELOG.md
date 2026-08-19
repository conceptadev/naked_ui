## 1.0.0-beta.12

### Features

- Add `NakedButton.semanticHint` on the same Semantics node as the button
  role, label, enabled state, and tap/long-press actions.
- Add `NakedSelect.semanticValue` so the trigger can announce a
  human-readable selection instead of `T.toString()`.
  `SemanticsRole.comboBox` exists on Flutter 3.41+ but debug semantics
  still throw `Missing checks for role` (flutter/flutter#172918), so the
  trigger keeps the merged button + expanded + value contract.
- Add `NakedRadioGroup`, a thin wrapper over Flutter's `RadioGroup` that
  supplies what it lacks: a nullable `onChanged` (null means disabled), a
  group `enabled` state radios inherit, and an optional accessible group
  label. Flutter's `RadioGroup` keeps the single `SemanticsRole.radioGroup`
  node; the label is a plain container around it, never a second role node.

## 1.0.0-beta.11

### Features

- Add dependency-free `NakedLink` with Link semantics, optional destination
  metadata, caller-owned activation, observable hover/focus/press/disabled
  state, and caller-owned focus nodes. Primary tap, semantic tap, Enter, and
  Numpad Enter activate; Space and held-key repeats remain unclaimed. Inert
  Links expose no Link role, destination, focus stop, or tap action.

## 1.0.0-beta.10

### Features

- Add `NakedAccordion.itemBuilder` for styling a trigger and panel as one unit.
  It receives the same `NakedAccordionItemState` as the trigger builder plus the
  fully assembled item as its child, and its context resolves
  `NakedAccordionItemState.controllerOf` to the authoritative controller shared
  with the trigger and panel.

### Fixes

- Track `NakedAccordion` press state whenever the item is enabled instead of
  only when `onPressChange` is supplied, so `WidgetState.pressed` reaches
  builders without a callback, and clear the pressed state when the item
  becomes disabled.

## 1.0.0-beta.9

### Fixes

- Keep `NakedTextField`'s `WidgetState.pressed`, `onTapChange`, and
  `onPressChange` synchronized when selection gestures take over; block
  disabled pointer and selection paths, and defer lifecycle cleanup callbacks
  to avoid rebuilding while the widget tree is locked.
- Mark `NakedToggleOption` semantics as part of a mutually exclusive group,
  matching Flutter's segmented-control contract for enabled, selected, and
  disabled options.

## 1.0.0-beta.8

### Fixes

- Preserve tooltip overlay semantics when `semanticLabel` is absent or blank,
  while continuing to avoid duplicate announcements when a non-empty label
  represents the content on the trigger. Explicit semantics overrides remain
  authoritative.

## 1.0.0-beta.7

### Features

- Add `NakedSliderState.visualPercentageOf` for mapping arbitrary logical
  fractions to physical track alignment across orientation, text direction,
  and inversion, while preserving `visualPercentageAt` thumb placement.

## 1.0.0-beta.6

### Fixes

- Make `NakedTextField` honor ambient `DefaultSelectionStyle` cursor and
  selection colors, including context-resolved `CupertinoDynamicColor`
  variants, while preserving explicit cursor precedence, focus gating, and
  platform fallbacks.

### Maintenance

- Point package metadata at the canonical `conceptadev/naked_ui` repository.

## 1.0.0-beta.5

### Breaking changes

- Replace alignment-pair overlay positioning with a Radix-shaped
  `OverlayPositionConfig`: side, logical alignment, signed side/alignment
  offsets, collision padding, collision avoidance, and a resolved
  `OverlayPlacement` available to overlay descendants after flip or shift.
- Change `NakedSlider` from one `double value` to a nonempty, ordered
  `List<double> values`. Callbacks are list-valued; defaults are now `min=0`,
  `max=100`, and `step=1`. The slider supports arbitrary thumb counts,
  orientation, inversion, minimum spacing, nearest-thumb pointer selection,
  non-crossing constraints, and per-thumb focus, labels, formatters, and
  semantics actions.

### Features and behavior changes

- Add controlled `open` / `onOpenChanged` contracts to Select and Tooltip.
  Controlled owners may accept or reject trigger, selection, Escape, outside
  tap, hover, focus, and touch requests without transient visual mutation.
- Keep Tooltip open while either its trigger or overlay content is hovered,
  with an opt-out through `disableHoverableContent`; expose the final
  collision-resolved placement to tooltip content.
- Add separate keyed Popover anchors and automatic/manual Tabs activation.
- Add controlled menu checkbox items and typed radio groups/items with checked
  roles and mutually-exclusive semantics.
- Add recursively composable submenus with delayed hover handoff, LTR/RTL
  open/close arrows, Escape handling, sibling coordination, root dismissal,
  first-item focus, and trigger-focus restoration.

## 1.0.0-beta.4

### Features

- Add `SemanticsRole.alertDialog` support to `NakedDialog` and a
  `showNakedAlertDialog` helper with required non-empty caller-localized names,
  a non-dismissible outside barrier by default, null cancellation from Escape
  and platform Back, mandatory focus entry, safe initial-focus selection,
  closed-loop traversal, and caller-owned focus-node handling. Dismissible
  barriers require a non-empty localized label. Existing `NakedDialog` and
  `showNakedDialog` defaults remain unchanged.

### Behavior changes

- Migrate `NakedToggleGroup` options from independent Tab stops to one
  roving-focus stop: Tab enters and exits once, arrows and Home/End move focus
  without selecting, activation proposes the controlled value, and disabled or
  dynamically removed options repair focus within the group.

## 1.0.0-beta.3

### Fixes and hardening

- Scope overlay-item builders to their declared state type: `NakedMenuItem` and
  `NakedSelectOption` builders now receive a context containing a matching
  `NakedStateScope<S>`, so `NakedMenuItemState`/`NakedSelectOptionState`'s
  `of`/`controllerOf` helpers resolve to the item state. Downstream code no
  longer needs `NakedButtonState`, which leaked the internal button
  implementation.

## 1.0.0-beta.2

### Breaking changes

- Require Dart 3.9 and Flutter 3.41, matching the `RawTooltip` API used by the
  package.
- Treat `NakedSelect.value` as fully controlled, including `null`; a select
  without `onChanged` is now consistently non-interactive.
- Make `NakedAccordionController.values` immutable to callers and preserve its
  observable FIFO ordering.
- Make `NakedStateScope.controllerOf` type-specific; generic state helpers now
  require the requested value type.
- Require `NakedMenu` to have either a `child` or `builder`, and throw a
  descriptive error when menu/select items are used outside their owner.

### Fixes and hardening

- Rebuild controller-driven tabs, prevent duplicate tab selection callbacks,
  replace duplicated content semantics when `semanticLabel` is set, and keep
  orientation-aware Home/End navigation within each tab bar.
- Apply dialog, tab, menu, and menu-item semantic roles, including selected
  state for select options.
- Correct focus-node ownership swaps across controls and remove the redundant
  focus owner around `EditableText`.
- Consolidate overlay positioning, including safe handling of oversized
  content, and rebuild Popover on the shared anchored-overlay shell.
- Keep inherited callbacks current, initialize replacement accordion
  controllers, and scope slider drag-end values to each drag session.
- Correct example paths in CI workflows and remove redundant dependency steps.

## 1.0.0-beta.1

- feat(naked-select): add `mouseCursor` property to NakedSelect
- refactor(naked-tooltip): replace `RawMenuAnchor` with `RawTooltip`
- fix: stabilize flaky tests (InkSparkle shader + focus mode)

## 0.2.0-beta.7

- fix: text style handling in NakedTextField
- feat: improve 3.27-safe semantics for menu, select, accordion, checkbox, radio, slider, and text field

## 0.2.0-beta.6

- fix: disabled and error state support for NakedTextField

## 0.2.0-beta.5

- fix: NakedAccordionItemState scope on content
- refactor: remove NakedMenuController typedef

## 0.2.0-beta.4

- docs: refine documentation for developer clarity
- refactor: Simplify NakedTextFieldBuilder signature
- feat: add excludeSemantics parameter to all widgets

## 0.2.0-beta.3

- feat: expose StrutStyle to NakedTextField
- fix: state scope not in the Context
- feat: recreate NakedTooltip widget
- refactor: Overlay Rendering
- docs: Improve the usage examples

## 0.2.0-beta.2

### Bug Fixes

- Fixed `.when` method priority order to prioritize active interaction states (dragged) before selection states

### Improvements

- Added comprehensive test coverage for mixins and utilities

## 0.2.0-beta.1

- Added: Popover; Toggle
- API: Standardized state callbacks (onHoverChange/onPressChange/onFocusChange); removed onDisabledState (use enabled); added onSelectChange/onDragChange where applicable
- Better use of Raw Flutter components where available
- Accessibility: Improved semantics across button, checkbox, radio, slider, select, tabs, dialog, tooltip
- Focus/State: Unified focus handling (FocusNodeMixin) and consistent hover/press/selected for builders

- Architecture: Builder-first APIs (e.g., NakedTextField builder) with state provided via NakedStateScope

## 0.0.1-dev.2 (2025-07-03)

### Features

* "Naked" - A Behavior-First UI Component Library for Flutter ([#579](https://github.com/btwld/naked_ui/issues/579)) ([c55b55f](https://github.com/btwld/naked_ui/commit/c55b55ffa47206fd49da9eebf85e834b5f08220e))
* Add maybeOf helper to InheritedWidgets and refactor of() ([805a37e](https://github.com/btwld/naked_ui/commit/805a37e5a2924e79fe08784ff9ac52b20e59bc44))
* Add maybeOf helper to InheritedWidgets and refactor of() ([805a37e](https://github.com/btwld/naked_ui/commit/805a37e5a2924e79fe08784ff9ac52b20e59bc44))
* Add test for Hover to RadioButton ([#601](https://github.com/btwld/naked_ui/issues/601)) ([8bd0425](https://github.com/btwld/naked_ui/commit/8bd0425150e9d81a03f9885ad493da47ea1080b2))
* Add textStyle prop in NakedTextField  ([#608](https://github.com/btwld/naked_ui/issues/608)) ([4b5252b](https://github.com/btwld/naked_ui/commit/4b5252b7a49d21695a97e806fef5fd9f2d21555a))
* Implement Tooltip Lifecycle ([#603](https://github.com/btwld/naked_ui/issues/603)) ([2ddbf60](https://github.com/btwld/naked_ui/commit/2ddbf60b0a6093b41c193a4fd42259cc40519810))
* Recreate Button using Naked ([#587](https://github.com/btwld/naked_ui/issues/587)) ([0d55724](https://github.com/btwld/naked_ui/commit/0d5572437d4963f13572402128b6a7a85e60aab1))
* Refactor radio and checkbox components with new architecture ([#672](https://github.com/btwld/naked_ui/issues/672)) ([4f3ce7d](https://github.com/btwld/naked_ui/commit/4f3ce7d4023710adb9cc7f4ba751e78d8fe3f3c2))


### Bug Fixes

* Change default autofocus to false in Menu and Select ([#609](https://github.com/btwld/naked_ui/issues/609)) ([76d8736](https://github.com/btwld/naked_ui/commit/76d873661f7cec60195e1a0bdec530936decc82e))


### Miscellaneous Chores

* release 0.0.1-dev.2 ([399a65d](https://github.com/btwld/naked_ui/commit/399a65d6ebe2a5b2089dd233721f91a04dfe9e97))
* release 0.0.1-dev.2 ([6d1ff7f](https://github.com/btwld/naked_ui/commit/6d1ff7fa42c9b47191c5f3e8ac8ec2f26565d29f))
* release 0.0.1-dev.2 ([c1b981e](https://github.com/btwld/naked_ui/commit/c1b981ea029d3da7d7cd25f3197e27b049789d72))

## 0.0.1-dev.0

* Initial development release
* Core functionality for HeadlessButton component
* State management via HeadlessInteractiveStateController
* Support for interactive states (disabled, focused, hovered, pressed)
* Fully customizable rendering via builder pattern
