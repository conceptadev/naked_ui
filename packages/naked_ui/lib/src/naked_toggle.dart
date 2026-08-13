import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'mixins/naked_mixins.dart';
import 'utilities/intents.dart';
import 'utilities/naked_focusable_detector.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/state.dart';

/// Immutable view passed to [NakedToggle.builder].
class NakedToggleState extends NakedState {
  /// Whether the toggle is currently on.
  final bool isToggled;

  /// Creates an immutable snapshot of binary toggle state.
  NakedToggleState({required super.states, required this.isToggled});

  /// Returns the nearest [NakedToggleState] from context.
  static NakedToggleState of(BuildContext context) => NakedState.of(context);

  /// Returns the nearest [NakedToggleState] if available.
  static NakedToggleState? maybeOf(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf(BuildContext context) =>
      NakedState.controllerOf<NakedToggleState>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf(BuildContext context) =>
      NakedState.maybeControllerOf<NakedToggleState>(context);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedToggleState &&
        statesEqual(other) &&
        other.isToggled == isToggled;
  }

  @override
  int get hashCode => Object.hash(statesHashCode, isToggled);
}

/// Immutable view passed to [NakedToggleOption.builder].
class NakedToggleOptionState<T> extends NakedState {
  /// The option's value.
  final T value;

  /// Creates an immutable snapshot for the option associated with [value].
  NakedToggleOptionState({required super.states, required this.value});

  /// Returns the nearest [NakedToggleOptionState] of the requested type.
  static NakedToggleOptionState<S> of<S>(BuildContext context) =>
      NakedState.of(context);

  /// Returns the nearest [NakedToggleOptionState] if available.
  static NakedToggleOptionState<S>? maybeOf<S>(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf<S>(BuildContext context) =>
      NakedState.controllerOf<NakedToggleOptionState<S>>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf<S>(BuildContext context) =>
      NakedState.maybeControllerOf<NakedToggleOptionState<S>>(context);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedToggleOptionState<T> &&
        statesEqual(other) &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(statesHashCode, value);
}

/// A headless binary toggle control without visuals.
///
/// Behaves as a toggle button or switch based on [asSwitch]. The builder receives
/// a [NakedToggleState] with the toggle value and interaction states.
///
/// ```dart
/// NakedToggle(
///   value: isToggled,
///   onChanged: (value) => setState(() => isToggled = value),
///   child: MyCustomToggleUI(),
/// )
/// ```
///
/// See also:
/// - [NakedCheckbox], for a boolean form control alternative.
/// - [NakedRadio], for exclusive selection among options.

class NakedToggle extends StatefulWidget {
  /// Creates a headless binary toggle controlled by [value].
  const NakedToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.child,
    this.enabled = true,
    this.mouseCursor,
    this.enableFeedback = true,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.onHoverChange,
    this.onPressChange,
    this.builder,
    this.semanticLabel,
    this.asSwitch = false,
    this.excludeSemantics = false,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       );

  /// The current selection state.
  final bool value;

  /// Called when selection changes.
  final ValueChanged<bool>? onChanged;

  /// The child widget; ignored if [builder] is provided.
  final Widget? child;

  /// Whether the control is interactive.
  final bool enabled;

  /// The mouse cursor when interactive.
  final MouseCursor? mouseCursor;

  /// Whether to provide platform feedback on interactions.
  final bool enableFeedback;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to autofocus.
  final bool autofocus;

  /// Called when focus changes.
  final ValueChanged<bool>? onFocusChange;

  /// Called when hover changes.
  final ValueChanged<bool>? onHoverChange;

  /// Called when the pressed state changes.
  final ValueChanged<bool>? onPressChange;

  /// Builds the toggle using the current [NakedToggleState].
  final ValueWidgetBuilder<NakedToggleState>? builder;

  /// Semantic label for screen readers.
  final String? semanticLabel;

  /// Whether to use switch semantics instead of button semantics.
  final bool asSwitch;

  /// Whether to exclude this widget from the semantic tree.
  ///
  /// When true, the widget and its children are hidden from accessibility services.
  final bool excludeSemantics;

  bool get _effectiveEnabled => enabled && onChanged != null;

  @override
  State<NakedToggle> createState() => _NakedToggleState();
}

class _NakedToggleState extends State<NakedToggle>
    with WidgetStatesMixin<NakedToggle> {
  void _activate() {
    if (!widget._effectiveEnabled) return;

    if (widget.enableFeedback) {
      if (widget.asSwitch) {
        HapticFeedback.selectionClick();
      } else {
        Feedback.forTap(context);
      }
    }

    widget.onChanged?.call(!widget.value);
  }

  Widget _buildContent() {
    final toggleState = NakedToggleState(
      states: widgetStates,
      isToggled: widget.value,
    );

    return NakedStateScopeBuilder(
      value: toggleState,
      child: widget.child,
      builder: widget.builder,
    );
  }

  Widget _buildToggle() {
    Widget gestureDetector = GestureDetector(
      onTapDown: widget._effectiveEnabled
          ? (_) => updatePressState(true, widget.onPressChange)
          : null,
      onTapUp: widget._effectiveEnabled
          ? (_) => updatePressState(false, widget.onPressChange)
          : null,
      onTap: widget._effectiveEnabled ? _activate : null,
      onTapCancel: widget._effectiveEnabled
          ? () => updatePressState(false, widget.onPressChange)
          : null,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      child: _buildContent(),
    );

    return widget.excludeSemantics
        ? ExcludeSemantics(child: gestureDetector)
        : Semantics(
            enabled: widget._effectiveEnabled,
            toggled: widget.value,
            button: !widget.asSwitch,
            label: widget.semanticLabel,
            onTap: widget._effectiveEnabled ? _activate : null,
            child: gestureDetector,
          );
  }

  MouseCursor get _effectiveCursor => widget._effectiveEnabled
      ? (widget.mouseCursor ?? SystemMouseCursors.click)
      : SystemMouseCursors.basic;

  @override
  void initializeWidgetStates() {
    updateDisabledState(!widget._effectiveEnabled);
    updateSelectedState(widget.value, null);
  }

  @override
  void didUpdateWidget(covariant NakedToggle oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget._effectiveEnabled != widget._effectiveEnabled) {
      final nowDisabled = !widget._effectiveEnabled;
      updateDisabledState(nowDisabled);
      if (nowDisabled) {
        updateState(WidgetState.hovered, false);
        updateState(WidgetState.pressed, false);
        updateState(WidgetState.focused, false);
      }
    }

    if (oldWidget.value != widget.value) {
      updateSelectedState(widget.value, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NakedFocusableDetector(
      enabled: widget._effectiveEnabled,
      autofocus: widget.autofocus,
      onFocusChange: (f) => updateFocusState(f, widget.onFocusChange),
      onHoverChange: (h) => updateHoverState(h, widget.onHoverChange),
      focusNode: widget.focusNode,
      mouseCursor: _effectiveCursor,
      shortcuts: NakedIntentActions.toggle.shortcuts,
      actions: NakedIntentActions.toggle.actions(
        onToggle: () {
          if (widget._effectiveEnabled) {
            _activate();
          }
        },
      ),
      child: _buildToggle(),
    );
  }
}

/// Headless single-select toggle group (segmented control-like).
///
/// Provides an inherited scope for items to read `selectedValue` and call
/// `onChanged` when activated. No styling is provided.
class NakedToggleGroup<T> extends StatefulWidget {
  /// Creates a single-select group controlled by [selectedValue].
  const NakedToggleGroup({
    super.key,
    required this.child,
    required this.selectedValue,
    this.onChanged,
    this.enabled = true,
    this.orientation = Axis.horizontal,
    this.loop = true,
    this.semanticLabel,
    this.excludeSemantics = false,
  });

  /// The widget containing toggle options.
  final Widget child;

  /// The currently selected value.
  final T? selectedValue;

  /// Called when selection changes.
  final ValueChanged<T?>? onChanged;

  /// The enabled state of the group.
  final bool enabled;

  /// The axis along which arrow keys move focus between options.
  final Axis orientation;

  /// Whether arrow-key focus movement wraps at either end of the group.
  final bool loop;

  /// The accessibility label for the group.
  final String? semanticLabel;

  /// Whether to hide the group and its options from accessibility services.
  final bool excludeSemantics;

  bool get _effectiveEnabled => enabled && onChanged != null;

  @override
  State<NakedToggleGroup<T>> createState() => _NakedToggleGroupState<T>();
}

class _NakedToggleGroupState<T> extends State<NakedToggleGroup<T>> {
  late final _ToggleGroupController<T> _controller = _ToggleGroupController<T>(
    this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    _controller.updateConfiguration(
      selectedValue: widget.selectedValue,
      enabled: widget._effectiveEnabled,
      orientation: widget.orientation,
      loop: widget.loop,
      textDirection: textDirection,
    );

    Widget result = FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: _ToggleScope<T>(
        controller: _controller,
        selectedValue: widget.selectedValue,
        onChanged: widget._effectiveEnabled ? widget.onChanged : null,
        enabled: widget._effectiveEnabled,
        orientation: widget.orientation,
        textDirection: textDirection,
        child: widget.child,
      ),
    );

    result = widget.excludeSemantics
        ? ExcludeSemantics(child: result)
        : Semantics(
            container: true,
            explicitChildNodes: true,
            label: widget.semanticLabel,
            child: result,
          );

    return result;
  }
}

class _ToggleScope<T> extends InheritedWidget {
  const _ToggleScope({
    required this.controller,
    required this.selectedValue,
    required this.onChanged,
    required this.enabled,
    required this.orientation,
    required this.textDirection,
    required super.child,
  });

  static _ToggleScope<T>? maybeOf<T>(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType();
  static _ToggleScope<T> of<T>(BuildContext context) {
    final scope = maybeOf<T>(context);
    if (scope == null) {
      throw FlutterError(
        'NakedToggleGroup<$T> scope not found. Wrap options in NakedToggleGroup.',
      );
    }

    return scope;
  }

  final _ToggleGroupController<T> controller;
  final T? selectedValue;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final Axis orientation;
  final TextDirection textDirection;

  int horizontalDeltaFor(LogicalKeyboardKey key) {
    final movesForward = key == LogicalKeyboardKey.arrowRight;
    if (textDirection == TextDirection.rtl) return movesForward ? -1 : 1;
    return movesForward ? 1 : -1;
  }

  @override
  bool updateShouldNotify(_ToggleScope<T> old) {
    return selectedValue != old.selectedValue ||
        enabled != old.enabled ||
        onChanged != old.onChanged ||
        orientation != old.orientation ||
        textDirection != old.textDirection;
  }
}

class _ToggleGroupEntry<T> {
  _ToggleGroupEntry(this.owner) {
    syncExternalFocusNode();
  }

  final _NakedToggleOptionState<T> owner;
  late T value;
  var effectiveEnabled = false;
  var autofocus = false;
  FocusNode? _managedExternalFocusNode;
  ({bool canRequestFocus, bool skipTraversal})? _originalExternalProperties;

  FocusNode get focusNode => owner.effectiveFocusNode;

  void syncExternalFocusNode() {
    final externalFocusNode = owner.widget.focusNode;
    if (identical(externalFocusNode, _managedExternalFocusNode)) return;

    restoreExternalFocusNode();
    if (externalFocusNode == null) return;

    _managedExternalFocusNode = externalFocusNode;
    _originalExternalProperties = (
      canRequestFocus: externalFocusNode.canRequestFocus,
      skipTraversal: externalFocusNode.skipTraversal,
    );
  }

  void restoreExternalFocusNode() {
    final externalFocusNode = _managedExternalFocusNode;
    final originalProperties = _originalExternalProperties;
    if (externalFocusNode != null && originalProperties != null) {
      externalFocusNode
        ..canRequestFocus = originalProperties.canRequestFocus
        ..skipTraversal = originalProperties.skipTraversal;
    }
    _managedExternalFocusNode = null;
    _originalExternalProperties = null;
  }
}

class _ToggleGroupController<T> {
  _ToggleGroupController(this.owner);

  final _NakedToggleGroupState<T> owner;
  final List<_ToggleGroupEntry<T>> _entries = [];
  final List<_ToggleGroupEntry<T>> _orderedEntries = [];

  _ToggleGroupEntry<T>? _target;
  _ToggleGroupEntry<T>? _lastFocused;
  _ToggleGroupEntry<T>? _focusedEntry;
  T? _selectedValue;
  var _enabled = false;
  var _orientation = Axis.horizontal;
  var _loop = true;
  var _textDirection = TextDirection.ltr;
  var _reconcileScheduled = false;
  var _disposed = false;
  var _autofocusHandled = false;
  ({int successorIndex, int predecessorIndex})? _pendingFocusRepair;

  _ToggleGroupEntry<T> register(_NakedToggleOptionState<T> option) {
    final entry = _ToggleGroupEntry<T>(option);
    _entries.add(entry);
    _orderedEntries.add(entry);
    _scheduleReconcile();
    return entry;
  }

  void unregister(_ToggleGroupEntry<T> entry, {bool repairFocus = true}) {
    if (!_entries.contains(entry)) return;

    final oldIndex = _orderedEntries.indexOf(entry);
    final repairFocusedEntry =
        repairFocus &&
        (entry.focusNode.hasFocus || identical(_focusedEntry, entry)) &&
        oldIndex >= 0;
    if (repairFocusedEntry) {
      _pendingFocusRepair = (
        successorIndex: oldIndex,
        predecessorIndex: oldIndex - 1,
      );
    }

    _entries.remove(entry);
    _orderedEntries.remove(entry);
    entry.restoreExternalFocusNode();
    if (identical(_target, entry)) _target = null;
    if (identical(_lastFocused, entry)) _lastFocused = null;
    if (identical(_focusedEntry, entry)) _focusedEntry = null;
    if (!repairFocusedEntry) {
      _choosePriorityTarget();
    }
    _scheduleReconcile();
  }

  void updateConfiguration({
    required T? selectedValue,
    required bool enabled,
    required Axis orientation,
    required bool loop,
    required TextDirection textDirection,
  }) {
    _selectedValue = selectedValue;
    _enabled = enabled;
    _orientation = orientation;
    _loop = loop;
    _textDirection = textDirection;
    _choosePriorityTarget();
    _scheduleReconcile();
  }

  void updateEntry(
    _ToggleGroupEntry<T> entry, {
    required T value,
    required bool effectiveEnabled,
    required bool autofocus,
  }) {
    entry.syncExternalFocusNode();
    final wasEnabled = entry.effectiveEnabled;
    final wasFocused =
        entry.focusNode.hasFocus || identical(_focusedEntry, entry);
    final oldIndex = _orderedEntries.indexOf(entry);
    final shouldRepairFocus =
        wasEnabled && !effectiveEnabled && wasFocused && oldIndex >= 0;
    entry
      ..value = value
      ..effectiveEnabled = effectiveEnabled
      ..autofocus = autofocus;

    if (shouldRepairFocus) {
      _pendingFocusRepair = (
        successorIndex: oldIndex,
        predecessorIndex: oldIndex - 1,
      );
    }

    if (!effectiveEnabled) {
      if (identical(_target, entry)) _target = null;
      if (identical(_lastFocused, entry)) _lastFocused = null;
      if (identical(_focusedEntry, entry)) _focusedEntry = null;
    }

    if (effectiveEnabled && wasFocused) {
      _focusedEntry = entry;
      _lastFocused = entry;
      _setTarget(entry);
    } else if (!shouldRepairFocus) {
      _choosePriorityTarget(preferredEntry: entry);
    }
    _applyFocusability(entry);
    _scheduleReconcile();
  }

  bool isRovingTarget(_ToggleGroupEntry<T> entry) =>
      _enabled && entry.effectiveEnabled && identical(_target, entry);

  void handleFocusChange(_ToggleGroupEntry<T> entry, bool focused) {
    if (focused && entry.effectiveEnabled) {
      _focusedEntry = entry;
      _lastFocused = entry;
      _target = entry;
      _scheduleReconcile();
      return;
    }
    if (!focused && identical(_focusedEntry, entry)) {
      scheduleMicrotask(() {
        if (!_disposed &&
            identical(_focusedEntry, entry) &&
            !entry.focusNode.hasFocus) {
          _focusedEntry = null;
        }
      });
    }
  }

  void move(_ToggleGroupEntry<T> entry, int delta) {
    if (!entry.effectiveEnabled) return;
    _refreshOrderedEntries();
    if (_orderedEntries.isEmpty) return;
    final currentIndex = _orderedEntries.indexOf(entry);
    if (currentIndex < 0) return;

    var index = currentIndex;
    for (var visited = 0; visited < _orderedEntries.length; visited++) {
      index += delta;
      if (index < 0 || index >= _orderedEntries.length) {
        if (!_loop) return;
        index = index < 0 ? _orderedEntries.length - 1 : 0;
      }

      final candidate = _orderedEntries[index];
      if (candidate.effectiveEnabled) {
        _focus(candidate);
        return;
      }
    }
  }

  void focusFirst() {
    _refreshOrderedEntries();
    for (final entry in _orderedEntries) {
      if (entry.effectiveEnabled) {
        _focus(entry);
        return;
      }
    }
  }

  void focusLast() {
    _refreshOrderedEntries();
    for (final entry in _orderedEntries.reversed) {
      if (entry.effectiveEnabled) {
        _focus(entry);
        return;
      }
    }
  }

  void _focus(_ToggleGroupEntry<T> entry) {
    if (!entry.effectiveEnabled) return;
    _setTarget(entry);
    entry.focusNode.requestFocus();
  }

  _ToggleGroupEntry<T>? _findRepairTarget({
    required int successorIndex,
    required int predecessorIndex,
  }) {
    for (var i = successorIndex; i < _orderedEntries.length; i++) {
      if (_orderedEntries[i].effectiveEnabled) return _orderedEntries[i];
    }

    final lastIndex = _orderedEntries.length - 1;
    for (var i = predecessorIndex.clamp(-1, lastIndex); i >= 0; i--) {
      if (_orderedEntries[i].effectiveEnabled) return _orderedEntries[i];
    }

    return null;
  }

  void _choosePriorityTarget({_ToggleGroupEntry<T>? preferredEntry}) {
    final validLastFocused =
        _lastFocused != null &&
        _entries.contains(_lastFocused) &&
        _lastFocused!.effectiveEnabled;
    if (validLastFocused) {
      _setTarget(_lastFocused);
      return;
    }

    if (preferredEntry != null &&
        preferredEntry.effectiveEnabled &&
        preferredEntry.value == _selectedValue) {
      _setTarget(preferredEntry);
      return;
    }

    for (final entry in _orderedEntries) {
      if (entry.effectiveEnabled && entry.value == _selectedValue) {
        _setTarget(entry);
        return;
      }
    }

    if (_target != null &&
        _entries.contains(_target) &&
        _target!.effectiveEnabled) {
      _applyAllFocusability();
      return;
    }

    for (final entry in _orderedEntries) {
      if (entry.effectiveEnabled) {
        _setTarget(entry);
        return;
      }
    }
    _setTarget(null);
  }

  void _setTarget(_ToggleGroupEntry<T>? entry) {
    _target = entry;
    _applyAllFocusability();
  }

  void _applyAllFocusability() {
    for (final entry in _entries) {
      _applyFocusability(entry);
    }
  }

  void _applyFocusability(_ToggleGroupEntry<T> entry) {
    entry.syncExternalFocusNode();
    final isEnabled = _enabled && entry.effectiveEnabled;
    entry.focusNode
      ..canRequestFocus = isEnabled
      ..skipTraversal = !isEnabled || !identical(_target, entry);
  }

  void _scheduleReconcile() {
    if (_disposed || _reconcileScheduled) return;
    _reconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (!_disposed && owner.mounted) _reconcile();
    });
  }

  void _reconcile() {
    _refreshOrderedEntries();

    final pendingFocusRepair = _pendingFocusRepair;
    _pendingFocusRepair = null;
    final repairTarget = pendingFocusRepair != null
        ? _findRepairTarget(
            successorIndex: pendingFocusRepair.successorIndex,
            predecessorIndex: pendingFocusRepair.predecessorIndex,
          )
        : null;

    if (repairTarget != null) {
      _lastFocused = repairTarget;
      _setTarget(repairTarget);
      repairTarget.focusNode.requestFocus();
    } else {
      _choosePriorityTarget();
    }

    if (!_autofocusHandled && _entries.any((entry) => entry.autofocus)) {
      _autofocusHandled = true;
      final autofocusEntry = _orderedEntries
          .where((entry) => entry.autofocus && entry.effectiveEnabled)
          .firstOrNull;
      if (autofocusEntry != null) {
        _setTarget(autofocusEntry);
        FocusScope.of(
          autofocusEntry.owner.context,
        ).autofocus(autofocusEntry.focusNode);
      }
    }
  }

  void _refreshOrderedEntries() {
    final attachedEntries = _entries
        .where(
          (entry) => entry.owner.mounted && entry.focusNode.context != null,
        )
        .toList();
    final visualEntries = _sortInVisualOrder(attachedEntries);

    _orderedEntries
      ..clear()
      ..addAll(visualEntries);
  }

  List<_ToggleGroupEntry<T>> _sortInVisualOrder(
    List<_ToggleGroupEntry<T>> entries,
  ) {
    if (entries.length < 2) return entries;

    final crossAxisSorted = [...entries]
      ..sort((a, b) {
        final aRect = a.focusNode.rect;
        final bRect = b.focusNode.rect;
        final crossAxisComparison = _compareCrossAxis(aRect, bRect);
        if (crossAxisComparison != 0) return crossAxisComparison;
        return _entries.indexOf(a).compareTo(_entries.indexOf(b));
      });

    final runs = <List<_ToggleGroupEntry<T>>>[];
    var currentRun = <_ToggleGroupEntry<T>>[];
    var runCrossAxisEnd = double.negativeInfinity;
    for (final entry in crossAxisSorted) {
      final bounds = _crossAxisBounds(entry.focusNode.rect);
      if (currentRun.isNotEmpty && bounds.start >= runCrossAxisEnd) {
        runs.add(currentRun);
        currentRun = <_ToggleGroupEntry<T>>[];
        runCrossAxisEnd = double.negativeInfinity;
      }
      currentRun.add(entry);
      if (bounds.end > runCrossAxisEnd) runCrossAxisEnd = bounds.end;
    }
    if (currentRun.isNotEmpty) runs.add(currentRun);

    for (final run in runs) {
      run.sort((a, b) {
        final aRect = a.focusNode.rect;
        final bRect = b.focusNode.rect;
        final primaryAxisComparison = _comparePrimaryAxis(aRect, bRect);
        if (primaryAxisComparison != 0) return primaryAxisComparison;
        return _entries.indexOf(a).compareTo(_entries.indexOf(b));
      });
    }
    return [for (final run in runs) ...run];
  }

  int _compareHorizontal(Rect a, Rect b) => _textDirection == TextDirection.ltr
      ? a.left.compareTo(b.left)
      : b.right.compareTo(a.right);

  int _compareCrossAxis(Rect a, Rect b) => _orientation == Axis.horizontal
      ? a.top.compareTo(b.top)
      : _compareHorizontal(a, b);

  int _comparePrimaryAxis(Rect a, Rect b) => _orientation == Axis.horizontal
      ? _compareHorizontal(a, b)
      : a.top.compareTo(b.top);

  ({double start, double end}) _crossAxisBounds(Rect rect) {
    if (_orientation == Axis.horizontal) {
      return (start: rect.top, end: rect.bottom);
    }
    if (_textDirection == TextDirection.ltr) {
      return (start: rect.left, end: rect.right);
    }
    return (start: -rect.right, end: -rect.left);
  }

  void dispose() {
    _disposed = true;
    for (final entry in _entries) {
      entry.restoreExternalFocusNode();
    }
    _entries.clear();
    _orderedEntries.clear();
    _target = null;
    _lastFocused = null;
    _focusedEntry = null;
    _pendingFocusRepair = null;
  }
}

class _ToggleGroupMoveIntent extends Intent {
  const _ToggleGroupMoveIntent(this.delta);

  final int delta;
}

class _ToggleGroupFirstIntent extends Intent {
  const _ToggleGroupFirstIntent();
}

class _ToggleGroupLastIntent extends Intent {
  const _ToggleGroupLastIntent();
}

/// A headless toggle option that participates in a [NakedToggleGroup].
///
/// Uses button-like semantics and exposes selected state via WidgetStates.
class NakedToggleOption<T> extends StatefulWidget {
  /// Creates a headless group option associated with [value].
  const NakedToggleOption({
    super.key,
    required this.value,
    this.child,
    this.enabled = true,
    this.mouseCursor,
    this.enableFeedback = true,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.onHoverChange,
    this.onPressChange,
    this.builder,
    this.semanticLabel,
    this.excludeSemantics = false,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       );

  /// The value selected when this option is activated.
  final T value;

  /// The option content when [builder] is not used.
  final Widget? child;

  /// Whether this option can be activated.
  final bool enabled;

  /// The cursor shown while hovering over an enabled option.
  final MouseCursor? mouseCursor;

  /// Whether activation provides platform feedback.
  final bool enableFeedback;

  /// The focus node used by this option.
  ///
  /// The caller owns disposal; the option manages its focusability and traversal
  /// properties while hosted.
  final FocusNode? focusNode;

  /// Whether this option requests focus when first built.
  final bool autofocus;

  /// Called when the option's focus state changes.
  final ValueChanged<bool>? onFocusChange;

  /// Called when the pointer enters or leaves the option.
  final ValueChanged<bool>? onHoverChange;

  /// Called when the option's pressed state changes.
  final ValueChanged<bool>? onPressChange;

  /// Builds the option from its current interaction and selection state.
  final ValueWidgetBuilder<NakedToggleOptionState<T>>? builder;

  /// The accessibility label for this option.
  final String? semanticLabel;

  /// Whether to exclude this widget from the semantic tree.
  ///
  /// When true, the widget and its children are hidden from accessibility services.
  final bool excludeSemantics;

  @override
  State<NakedToggleOption<T>> createState() => _NakedToggleOptionState<T>();
}

class _NakedToggleOptionState<T> extends State<NakedToggleOption<T>>
    with
        WidgetStatesMixin<NakedToggleOption<T>>,
        FocusNodeMixin<NakedToggleOption<T>> {
  @override
  FocusNode? get widgetProvidedNode => widget.focusNode;

  _ToggleScope<T>? _scope;
  _ToggleGroupEntry<T>? _entry;
  var _effectiveEnabledEpoch = 0;

  void _activate(_ToggleScope<T> scope) {
    final isEnabled = scope.enabled && widget.enabled;
    if (!isEnabled) return;
    if (widget.enableFeedback) HapticFeedback.selectionClick();
    if (scope.onChanged != null && scope.selectedValue != widget.value) {
      scope.onChanged!(widget.value);
    }
  }

  void _updateEffectiveEnabled(bool isEnabled) {
    if (!updateDisabledState(!isEnabled)) return;
    final epoch = ++_effectiveEnabledEpoch;
    if (isEnabled) return;

    final hoverCallback = updateHoverState(false, null)
        ? widget.onHoverChange
        : null;
    final pressCallback = updatePressState(false, null)
        ? widget.onPressChange
        : null;
    final focusCallback = updateFocusState(false, null)
        ? widget.onFocusChange
        : null;
    if (hoverCallback == null &&
        pressCallback == null &&
        focusCallback == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _effectiveEnabledEpoch == epoch && isDisabled) {
        hoverCallback?.call(false);
        pressCallback?.call(false);
        focusCallback?.call(false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = _ToggleScope.of<T>(context);
    if (!identical(_scope?.controller, scope.controller)) {
      final oldEntry = _entry;
      if (oldEntry != null) {
        _scope?.controller.unregister(oldEntry, repairFocus: false);
      }
      _entry = scope.controller.register(this);
    }
    _scope = scope;
    _syncEntry();
    final isEnabled = scope.enabled && widget.enabled;
    _updateEffectiveEnabled(isEnabled);
    updateSelectedState(scope.selectedValue == widget.value, null);
  }

  @override
  void didUpdateWidget(covariant NakedToggleOption<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scope = _ToggleScope.of<T>(context);
    _scope = scope;
    _syncEntry();
    _updateEffectiveEnabled(scope.enabled && widget.enabled);

    // If *this item's* value changed identity, recompute selected.
    if (widget.value != oldWidget.value) {
      updateSelectedState(scope.selectedValue == widget.value, null);
    }
  }

  void _syncEntry() {
    final scope = _scope;
    final entry = _entry;
    if (scope == null || entry == null) return;
    scope.controller.updateEntry(
      entry,
      value: widget.value,
      effectiveEnabled: scope.enabled && widget.enabled,
      autofocus: widget.autofocus,
    );
  }

  @override
  void dispose() {
    final entry = _entry;
    if (entry != null) _scope?.controller.unregister(entry);
    _entry = null;
    _scope = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _ToggleScope.of<T>(context);
    final entry = _entry!;
    final isEnabled = scope.enabled && widget.enabled;
    final isSelected = scope.selectedValue == widget.value;

    final optionState = NakedToggleOptionState<T>(
      states: widgetStates,
      value: widget.value,
    );

    final content = widget.builder != null
        ? widget.builder!(context, optionState, widget.child)
        : widget.child!;

    final wrappedContent = NakedStateScope(value: optionState, child: content);

    final cursor = isEnabled
        ? (widget.mouseCursor ?? SystemMouseCursors.click)
        : SystemMouseCursors.basic;

    Widget gestureDetector = GestureDetector(
      onTapDown: isEnabled
          ? (_) => updatePressState(true, widget.onPressChange)
          : null,
      onTapUp: isEnabled
          ? (_) => updatePressState(false, widget.onPressChange)
          : null,
      onTap: isEnabled ? () => _activate(scope) : null,
      onTapCancel: isEnabled
          ? () => updatePressState(false, widget.onPressChange)
          : null,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      child: wrappedContent,
    );

    Widget optionChild = widget.excludeSemantics
        ? ExcludeSemantics(child: gestureDetector)
        : Semantics(
            container: true,
            enabled: isEnabled,
            selected: isSelected,
            button: true,
            inMutuallyExclusiveGroup: true,
            label: widget.semanticLabel,
            onTap: isEnabled ? () => _activate(scope) : null,
            child: gestureDetector,
          );

    final shortcuts = <ShortcutActivator, Intent>{
      ...NakedIntentActions.toggle.shortcuts,
      if (scope.orientation == Axis.horizontal) ...{
        const SingleActivator(
          LogicalKeyboardKey.arrowLeft,
        ): _ToggleGroupMoveIntent(
          scope.horizontalDeltaFor(LogicalKeyboardKey.arrowLeft),
        ),
        const SingleActivator(
          LogicalKeyboardKey.arrowRight,
        ): _ToggleGroupMoveIntent(
          scope.horizontalDeltaFor(LogicalKeyboardKey.arrowRight),
        ),
      } else ...{
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const _ToggleGroupMoveIntent(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const _ToggleGroupMoveIntent(1),
      },
      const SingleActivator(LogicalKeyboardKey.home):
          const _ToggleGroupFirstIntent(),
      const SingleActivator(LogicalKeyboardKey.end):
          const _ToggleGroupLastIntent(),
    };
    final actions = <Type, Action<Intent>>{
      ...NakedIntentActions.toggle.actions(onToggle: () => _activate(scope)),
      _ToggleGroupMoveIntent: CallbackAction<_ToggleGroupMoveIntent>(
        onInvoke: (intent) => scope.controller.move(entry, intent.delta),
      ),
      _ToggleGroupFirstIntent: CallbackAction<_ToggleGroupFirstIntent>(
        onInvoke: (_) => scope.controller.focusFirst(),
      ),
      _ToggleGroupLastIntent: CallbackAction<_ToggleGroupLastIntent>(
        onInvoke: (_) => scope.controller.focusLast(),
      ),
    };

    return NakedFocusableDetector(
      enabled: isEnabled,
      autofocus: false,
      canRequestFocus: isEnabled,
      skipTraversal: !scope.controller.isRovingTarget(entry),
      descendantsAreTraversable: false,
      onFocusChange: (f) {
        scope.controller.handleFocusChange(entry, f);
        updateFocusState(f, widget.onFocusChange);
      },
      onHoverChange: (h) => updateHoverState(h, widget.onHoverChange),
      focusNode: effectiveFocusNode,
      mouseCursor: cursor,
      shortcuts: shortcuts,
      actions: actions,
      child: optionChild,
    );
  }
}
