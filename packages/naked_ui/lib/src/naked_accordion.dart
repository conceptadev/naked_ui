import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'mixins/naked_mixins.dart';
import 'utilities/intents.dart';
import 'utilities/naked_focusable_detector.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/state.dart';

/// Immutable state exposed to a [NakedAccordionGroup] container.
class NakedAccordionGroupState extends NakedState {
  /// Number of currently expanded items.
  final int expandedCount;

  /// Whether more items can be expanded based on [maxExpanded].
  final bool canExpandMore;

  /// Whether items can be collapsed based on [minExpanded].
  final bool canCollapseMore;

  /// The minimum number of expanded items allowed.
  final int minExpanded;

  /// The maximum number of expanded items allowed (null = unlimited).
  final int? maxExpanded;

  NakedAccordionGroupState._({
    required super.states,
    required this.expandedCount,
    required this.canExpandMore,
    required this.canCollapseMore,
    required this.minExpanded,
    required this.maxExpanded,
  });

  /// Creates a group snapshot and derives its expansion affordances.
  factory NakedAccordionGroupState({
    required Set<WidgetState> states,
    required int expandedCount,
    required int minExpanded,
    int? maxExpanded,
  }) {
    final canExpandMore = maxExpanded == null || expandedCount < maxExpanded;
    final canCollapseMore = expandedCount > minExpanded;

    return NakedAccordionGroupState._(
      states: states,
      expandedCount: expandedCount,
      canExpandMore: canExpandMore,
      canCollapseMore: canCollapseMore,
      minExpanded: minExpanded,
      maxExpanded: maxExpanded,
    );
  }

  /// Returns the nearest [NakedAccordionGroupState] from context.
  static NakedAccordionGroupState of(BuildContext context) =>
      NakedState.of(context);

  /// Returns the nearest [NakedAccordionGroupState] if available.
  static NakedAccordionGroupState? maybeOf(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf(BuildContext context) =>
      NakedState.controllerOf<NakedAccordionGroupState>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf(BuildContext context) =>
      NakedState.maybeControllerOf<NakedAccordionGroupState>(context);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedAccordionGroupState &&
        statesEqual(other) &&
        other.expandedCount == expandedCount &&
        other.canExpandMore == canExpandMore &&
        other.canCollapseMore == canCollapseMore &&
        other.minExpanded == minExpanded &&
        other.maxExpanded == maxExpanded;
  }

  @override
  int get hashCode => Object.hash(
    statesHashCode,
    expandedCount,
    canExpandMore,
    canCollapseMore,
    minExpanded,
    maxExpanded,
  );
}

/// Immutable state exposed to [NakedAccordion] builders.
class NakedAccordionItemState<T> extends NakedState {
  /// The item's unique identifier.
  final T value;

  /// Whether this item is currently expanded.
  final bool isExpanded;

  /// Whether this item can be collapsed while honoring [NakedAccordionController.min].
  final bool canCollapse;

  /// Whether this item can be expanded while honoring [NakedAccordionController.max].
  final bool canExpand;

  /// Creates an immutable snapshot for the accordion item identified by [value].
  NakedAccordionItemState({
    required super.states,
    required this.value,
    required this.isExpanded,
    required this.canCollapse,
    required this.canExpand,
  });

  /// Returns the nearest [NakedAccordionItemState] of the requested type.
  static NakedAccordionItemState<S> of<S>(BuildContext context) =>
      NakedState.of<NakedAccordionItemState<S>>(context);

  /// Returns the nearest [NakedAccordionItemState] if available.
  static NakedAccordionItemState<S>? maybeOf<S>(BuildContext context) =>
      NakedState.maybeOf<NakedAccordionItemState<S>>(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf<S>(BuildContext context) =>
      NakedState.controllerOf<NakedAccordionItemState<S>>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf<S>(BuildContext context) =>
      NakedState.maybeControllerOf<NakedAccordionItemState<S>>(context);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedAccordionItemState<T> &&
        statesEqual(other) &&
        other.value == value &&
        other.isExpanded == isExpanded &&
        other.canCollapse == canCollapse &&
        other.canExpand == canExpand;
  }

  @override
  int get hashCode =>
      Object.hash(statesHashCode, value, isExpanded, canCollapse, canExpand);
}

/// Maintains accordion expansion state without imposing visuals.
///
/// Enforces optional [min] and [max] constraints and exposes helper methods for
/// updating the expanded set.
///
/// See also:
/// - [NakedAccordionGroup], the container that uses this controller.
class NakedAccordionController<T> with ChangeNotifier {
  /// Minimum number of expanded items allowed when closing.
  final int min;

  /// Maximum number of expanded items allowed.
  ///
  /// When `null`, expansion count is unlimited.
  final int? max;

  final LinkedHashSet<T> _values = LinkedHashSet<T>();

  /// Creates a controller with optional expansion count constraints.
  NakedAccordionController({this.min = 0, this.max})
    : assert(min >= 0, 'min must be >= 0'),
      assert(max == null || max >= min, 'max must be >= min');

  /// Expanded values in insertion order (oldest → newest).
  ///
  /// The returned view is unmodifiable so all mutations continue to enforce
  /// [min], [max], FIFO eviction, and listener notification.
  Set<T> get values => UnmodifiableSetView<T>(_values);

  /// Reports whether the item with [value] is currently expanded.
  bool contains(T value) => _values.contains(value);

  /// Opens [value], evicting the oldest entry when [max] is reached.
  void open(T value) {
    if (_values.contains(value)) return; // no-op
    final maxValue = max;
    if (maxValue == 0) return; // never allow expands when max is zero
    if (maxValue != null && _values.length >= maxValue) {
      // Close oldest to make room.
      if (_values.isNotEmpty) {
        final oldest = _values.first;
        _values.remove(oldest);
      }
    }
    _values.add(value);
    notifyListeners();
  }

  /// Closes [value] while respecting the [min] floor.
  void close(T value) {
    if (!_values.contains(value)) return; // no-op
    if (min > 0 && _values.length <= min) return; // floor
    _values.remove(value);
    notifyListeners();
  }

  /// Toggles [value], applying both [min] and [max] constraints.
  void toggle(T value) {
    if (_values.contains(value)) {
      close(value); // close() will notify
    } else {
      open(value); // open() will notify
    }
  }

  /// Removes all expanded values but preserves the first [min] entries.
  void clear() {
    if (_values.isEmpty) return;
    if (min <= 0) {
      _values.clear();
      notifyListeners();

      return;
    }
    if (_values.length <= min) return; // already at/under floor
    final keep = _values.take(min).toList(growable: false);
    _values
      ..clear()
      ..addAll(keep);
    notifyListeners();
  }

  /// Opens [newValues] in order without exceeding [max], preserving FIFO.
  void openAll(Iterable<T> newValues) {
    final maxValue = max;
    if (maxValue == 0) return;
    var changed = false;
    for (final v in newValues) {
      if (_values.contains(v)) continue;
      if (maxValue != null && _values.length >= maxValue) {
        if (_values.isNotEmpty) {
          final oldest = _values.first;
          _values.remove(oldest);
        }
      }
      _values.add(v);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Replaces all expanded values with [newValues], respecting [max].
  ///
  /// This may produce fewer than [min] expanded items because it is a direct
  /// programmatic update. User-initiated closing still honors [min].
  void replaceAll(Iterable<T> newValues) {
    final target = (max != null) ? newValues.take(max!) : newValues;
    final next = LinkedHashSet<T>.of(target);
    if (listEquals(_values.toList(), next.toList())) return; // no change
    _values
      ..clear()
      ..addAll(next);
    notifyListeners();
  }
}

/// Provides a [NakedAccordionController] to descendant widgets.
///
/// This extends [InheritedNotifier] to automatically notify dependents when
/// the controller's state changes, eliminating the need for explicit
/// [ListenableBuilder] wrappers in accordion items.
///
/// All accordion items rebuild when any item changes state - this is intentional
/// as Flutter's Element reconciliation efficiently handles widget reuse, and
/// typical accordion usage involves only 2-5 items where optimization overhead
/// exceeds any benefit.
class NakedAccordionScope<T>
    extends InheritedNotifier<NakedAccordionController<T>> {
  /// Creates a scope that exposes [controller] to [child].
  const NakedAccordionScope({
    super.key,
    required NakedAccordionController<T> controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller managing accordion expansion state.
  ///
  /// This is guaranteed non-null because the constructor requires it.
  NakedAccordionController<T> get controller => notifier!;

  /// Returns the nearest [NakedAccordionScope] without asserting.
  static NakedAccordionScope<T>? maybeOf<T>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NakedAccordionScope<T>>();
  }

  /// Returns the nearest [NakedAccordionScope], throwing when absent.
  static NakedAccordionScope<T> of<T>(BuildContext context) {
    final scope = maybeOf<T>(context);
    if (scope == null) {
      throw StateError('NakedAccordionScope<$T> not found in context.');
    }
    return scope;
  }
}

/// A headless accordion without visuals.
///
/// Contains expandable/collapsible sections managed by
/// [NakedAccordionController].
///
/// ```dart
/// final controller = NakedAccordionController<String>();
/// NakedAccordionGroup<String>(
///   controller: controller,
///   children: [
///     NakedAccordion(
///       value: 'section1',
///       builder: (context, state) => Text('Section 1'),
///       child: Text('Content 1'),
///     ),
///   ],
/// )
/// ```
///
/// See also:
/// - [ExpansionPanelList], the Material-styled accordion for typical apps.
class NakedAccordionGroup<T> extends StatefulWidget {
  /// Creates a group managed by [controller].
  const NakedAccordionGroup({
    super.key,
    required this.child,
    required this.controller,
    this.initialExpandedValues = const [],
  });

  /// Accordion items to render.
  final Widget child;

  /// Controller that manages expanded values.
  final NakedAccordionController<T> controller;

  /// Values expanded on the first build when the controller is empty.
  ///
  /// Updated values apply only while the controller remains empty to avoid
  /// clobbering user interaction.
  final List<T> initialExpandedValues;

  @override
  State<NakedAccordionGroup<T>> createState() => _NakedAccordionGroupState<T>();
}

class _NakedAccordionGroupState<T> extends State<NakedAccordionGroup<T>> {
  NakedAccordionController<T> get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (widget.initialExpandedValues.isNotEmpty && _controller.values.isEmpty) {
      _controller.replaceAll(widget.initialExpandedValues);
    }
  }

  @override
  void didUpdateWidget(covariant NakedAccordionGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.controller != widget.controller ||
            !listEquals(
              oldWidget.initialExpandedValues,
              widget.initialExpandedValues,
            )) &&
        _controller.values.isEmpty) {
      _controller.replaceAll(widget.initialExpandedValues);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NakedAccordionScope (InheritedNotifier) notifies dependents when
    // controller state changes. The Builder below depends on the scope,
    // so it rebuilds and updates NakedAccordionGroupState automatically.
    return NakedAccordionScope<T>(
      controller: _controller,
      child: Builder(
        builder: (context) {
          // Create dependency on the InheritedNotifier.
          // When controller notifies, this Builder rebuilds.
          context.dependOnInheritedWidgetOfExactType<NakedAccordionScope<T>>();

          return NakedStateScope(
            value: NakedAccordionGroupState(
              states: const {},
              expandedCount: _controller.values.length,
              minExpanded: _controller.min,
              maxExpanded: _controller.max,
            ),
            child: FocusTraversalGroup(child: widget.child),
          );
        },
      ),
    );
  }
}

/// Builds an accordion trigger from its current item [state].
typedef NakedAccordionTriggerBuilder<T> =
    Widget Function(BuildContext context, NakedAccordionItemState<T> state);

/// A headless accordion item with a customizable trigger and panel.
///
/// The [builder] receives a [NakedAccordionItemState] that includes
/// expansion status, constraint affordances, and interaction states.
/// The optional [itemBuilder] receives the same state around the fully
/// assembled trigger and panel.
///
/// See also:
/// - [NakedAccordionGroup], the container that manages accordion items.
class NakedAccordion<T> extends StatefulWidget {
  /// Creates a headless accordion item identified by [value].
  const NakedAccordion({
    super.key,
    required this.builder,
    required this.value,
    required this.child,
    this.itemBuilder,
    this.transitionBuilder,
    this.enabled = true,
    this.mouseCursor = SystemMouseCursors.click,
    this.enableFeedback = true,
    this.autofocus = false,
    this.focusNode,
    this.onFocusChange,
    this.onHoverChange,
    this.onPressChange,
    this.semanticLabel,
    this.excludeSemantics = false,
  });

  /// Builds the header or trigger for the item.
  final NakedAccordionTriggerBuilder<T> builder;

  /// Builds a presentation wrapper around the fully assembled item.
  ///
  /// The supplied child contains the interactive trigger followed by the
  /// transitioned panel. The callback context is below the item state scope,
  /// so it can access [NakedAccordionItemState.controllerOf].
  final ValueWidgetBuilder<NakedAccordionItemState<T>>? itemBuilder;

  /// Optional transition builder applied to the expanding panel.
  final Widget Function(Widget panel)? transitionBuilder;

  /// Content rendered while expanded.
  final Widget child;

  /// Unique identifier tracked by the controller.
  final T value;

  /// Called when the header's focus state changes.
  final ValueChanged<bool>? onFocusChange;

  /// Called when the header's hover state changes.
  final ValueChanged<bool>? onHoverChange;

  /// Called when the header's pressed state changes.
  final ValueChanged<bool>? onPressChange;

  /// Semantic label announced for the header.
  final String? semanticLabel;

  /// Whether the header is interactive.
  final bool enabled;

  /// Mouse cursor to use when interactive.
  final MouseCursor mouseCursor;

  /// Whether to provide platform feedback on interactions.
  final bool enableFeedback;

  /// Whether the header should autofocus.
  final bool autofocus;

  /// Focus node associated with the header.
  final FocusNode? focusNode;

  /// Whether to exclude this widget from the semantic tree.
  ///
  /// When true, the widget and its children are hidden from accessibility services.
  final bool excludeSemantics;

  @override
  State<NakedAccordion<T>> createState() => _NakedAccordionState<T>();
}

class _NakedAccordionState<T> extends State<NakedAccordion<T>>
    with WidgetStatesMixin<NakedAccordion<T>> {
  void _toggle(NakedAccordionController<T> controller) =>
      controller.toggle(widget.value);

  @override
  void initializeWidgetStates() {
    updateDisabledState(!widget.enabled);
  }

  @override
  void didUpdateWidget(covariant NakedAccordion<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      updateDisabledState(!widget.enabled);
      if (!widget.enabled) {
        updatePressState(false, widget.onPressChange);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the controller from scope. This creates a dependency on
    // NakedAccordionScope (InheritedNotifier), so this widget rebuilds
    // automatically when controller state changes.
    final controller = NakedAccordionScope.of<T>(context).controller;

    return _buildContent(context, controller);
  }

  Widget _buildContent(
    BuildContext context,
    NakedAccordionController<T> controller,
  ) {
    // Derive state directly from controller.
    final isExpanded = controller.contains(widget.value);
    final canCollapse =
        isExpanded && (controller.values.length > controller.min);
    final canExpand =
        !isExpanded &&
        (controller.max == null || controller.values.length < controller.max!);

    // Build the panel only when expanded.
    final Widget panel = isExpanded ? widget.child : const SizedBox.shrink();

    void onTap() {
      if (!widget.enabled) return;
      if (widget.enableFeedback) Feedback.forTap(context);
      _toggle(controller);
    }

    final accordionState = NakedAccordionItemState<T>(
      states: widgetStates,
      value: widget.value,
      isExpanded: isExpanded,
      canCollapse: canCollapse,
      canExpand: canExpand,
    );

    final scopedItem = NakedStateScopeBuilder<NakedAccordionItemState<T>>(
      value: accordionState,
      builder: (context, accordionState, _) {
        final trigger = widget.builder(context, accordionState);
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

        final semanticTrigger = widget.excludeSemantics
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
          child: semanticTrigger,
        );
        final transitionedPanel =
            widget.transitionBuilder?.call(panel) ?? panel;
        final assembledItem = Column(
          mainAxisSize: MainAxisSize.min,
          children: [focusableTrigger, transitionedPanel],
        );

        final itemBuilder = widget.itemBuilder;
        return itemBuilder == null
            ? assembledItem
            : itemBuilder(context, accordionState, assembledItem);
      },
    );

    return widget.excludeSemantics
        ? ExcludeSemantics(child: scopedItem)
        : scopedItem;
  }
}
