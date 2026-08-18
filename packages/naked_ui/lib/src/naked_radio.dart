import 'package:flutter/material.dart';

import 'mixins/naked_mixins.dart';
import 'utilities/hit_testable_container.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/state.dart';

/// Immutable view passed to [NakedRadio.builder].
class NakedRadioState<T> extends NakedState {
  /// The value represented by this radio.
  final T value;

  /// Creates an immutable snapshot for the radio associated with [value].
  NakedRadioState({required super.states, required this.value});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedRadioState<T> &&
        statesEqual(other) &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(statesHashCode, value);

  /// Returns the nearest [NakedRadioState] of the requested type.
  static NakedRadioState<S> of<S>(BuildContext context) =>
      NakedState.of(context);

  /// Returns the nearest [NakedRadioState] if available, otherwise null.
  static NakedRadioState<S>? maybeOf<S>(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf<S>(BuildContext context) =>
      NakedState.controllerOf<NakedRadioState<S>>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf<S>(BuildContext context) =>
      NakedState.maybeControllerOf<NakedRadioState<S>>(context);
}

/// A headless radio without visuals.
///
/// Must be placed under a [RadioGroup]. The builder receives a [NakedRadioState]
/// with the radio value, group value, and interaction states.
///
/// ```dart
/// RadioGroup<String>(
///   value: selectedValue,
///   onChanged: (value) => setState(() => selectedValue = value),
///   child: Column(children: [
///     NakedRadio(value: 'option1', child: Text('Option 1')),
///     NakedRadio(value: 'option2', child: Text('Option 2')),
///   ]),
/// )
/// ```
///
/// ## Accessibility
/// For optimal accessibility, ensure your radio has a minimum touch target
/// of 48x48dp. Smaller sizes will work but may be difficult for some users
/// to tap accurately.
///
/// See also:
/// - [Radio], the Material-styled radio for typical apps.
/// - [RadioGroup], which manages the selected value and provides grouping.
class NakedRadio<T> extends StatefulWidget {
  /// Creates a headless radio associated with [value].
  const NakedRadio({
    super.key,
    required this.value,
    this.child,
    this.enabled = true,
    this.mouseCursor,
    this.focusNode,
    this.autofocus = false,
    this.toggleable = false,
    this.onFocusChange,
    this.onHoverChange,
    this.onPressChange,
    this.builder,
    this.groupRegistry,
    this.semanticLabel,
    this.excludeSemantics = false,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       );

  /// The value represented by this radio.
  final T value;

  /// The visual content when not using [builder].
  final Widget? child;

  /// Whether the radio is enabled.
  final bool enabled;

  /// The mouse cursor when hovering.
  final MouseCursor? mouseCursor;

  /// The focus node for the radio.
  final FocusNode? focusNode;

  /// Whether to autofocus.
  final bool autofocus;

  /// Whether tapping the selected radio clears the selection.
  final bool toggleable;

  /// Called when focus changes.
  final ValueChanged<bool>? onFocusChange;

  /// Called when hover changes.
  final ValueChanged<bool>? onHoverChange;

  /// Called when press state changes.
  final ValueChanged<bool>? onPressChange;

  /// Builds the radio using the current [NakedRadioState].
  final ValueWidgetBuilder<NakedRadioState<T>>? builder;

  /// The registry override for advanced usage and testing.
  ///
  /// When null, the nearest [RadioGroup] ancestor is used.
  final RadioGroupRegistry<T>? groupRegistry;

  /// Semantic label for assistive technologies.
  final String? semanticLabel;

  /// Whether to hide this radio and its visual subtree from accessibility.
  final bool excludeSemantics;

  @override
  State<NakedRadio<T>> createState() => _NakedRadioState<T>();
}

class _NakedRadioState<T> extends State<NakedRadio<T>>
    with FocusNodeMixin<NakedRadio<T>> {
  bool? _lastReportedPressed;
  bool? _lastReportedHover;

  @protected
  @override
  FocusNode? get widgetProvidedNode => widget.focusNode;

  @protected
  @override
  ValueChanged<bool>? get onFocusChange => widget.onFocusChange;

  @override
  void didUpdateWidget(covariant NakedRadio<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When enablement flips, clear sentinels so the next interactive state
    // change is reported instead of being suppressed by stale values.
    if (oldWidget.enabled != widget.enabled) {
      _lastReportedHover = null;
      _lastReportedPressed = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final registry = widget.groupRegistry ?? RadioGroup.maybeOf<T>(context);
    if (registry == null) {
      throw FlutterError(
        'NakedRadio<$T> must be used within a RadioGroup<$T>.',
      );
    }

    // Typed to match the registry lookup above: with nested groups of
    // different value types, this radio must read the enabled state of the
    // same group that registered it, not merely the nearest one.
    final groupEnabled =
        NakedRadioGroupScope.maybeOf<T>(context)?.enabled ?? true;
    final effectiveEnabled = widget.enabled && groupEnabled;

    final effectiveCursor =
        widget.mouseCursor ??
        (effectiveEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic);

    final radio = RawRadio<T>(
      value: widget.value,
      mouseCursor: WidgetStateMouseCursor.resolveWith((_) => effectiveCursor),
      toggleable: widget.toggleable,
      focusNode: effectiveFocusNode, // FocusNodeMixin guarantees non-null
      autofocus: widget.autofocus && effectiveEnabled,
      groupRegistry: registry,
      enabled: effectiveEnabled,
      builder: (context, radioState) {
        // Derive "pressed" from RawRadio's internal down position to avoid
        // intercepting gestures with an external Listener.
        final bool pressed = radioState.downPosition != null;
        final states = {...radioState.states, if (pressed) WidgetState.pressed};

        // Notify hover changes only when interactive, without setState in build
        final hovered = states.contains(WidgetState.hovered);
        if (effectiveEnabled && _lastReportedHover != hovered) {
          _lastReportedHover = hovered;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onHoverChange?.call(hovered);
          });
        }

        // Notify press changes only when interactive
        if (effectiveEnabled && _lastReportedPressed != pressed) {
          _lastReportedPressed = pressed;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onPressChange?.call(pressed);
          });
        }

        final isSelected = registry.groupValue == widget.value;
        final statesWithSelection = {
          ...states,
          if (isSelected) WidgetState.selected,
        };
        final radioStateTyped = NakedRadioState<T>(
          states: statesWithSelection,
          value: widget.value,
        );

        // Ensure the area is hit-testable so RawRadio's GestureDetector
        // can receive taps even if the built widget has no gesture handlers.
        Widget radioChild = HitTestableContainer(
          child: NakedStateScopeBuilder(
            value: radioStateTyped,
            child: widget.child,
            builder: widget.builder,
          ),
        );

        if (widget.semanticLabel != null) {
          radioChild = ExcludeSemantics(child: radioChild);
        }

        return radioChild;
      },
    );

    final result = widget.semanticLabel == null
        ? radio
        : Semantics(label: widget.semanticLabel, child: radio);

    return widget.excludeSemantics ? ExcludeSemantics(child: result) : result;
  }
}

/// Groups [NakedRadio] children under Flutter's [RadioGroup].
///
/// Owns the Flutter radio registry, group enabled state, the disabled
/// callback adaptation [RadioGroup] requires, and optional group
/// semantics. A null [onChanged] is a genuinely disabled group.
class NakedRadioGroup<T> extends StatelessWidget {
  /// Creates a radio group.
  const NakedRadioGroup({
    super.key,
    required this.groupValue,
    this.onChanged,
    this.enabled = true,
    this.semanticLabel,
    required this.child,
  });

  /// The currently selected value.
  final T? groupValue;

  /// Called when a radio in the group is selected.
  ///
  /// When null, the group is disabled. Flutter's [RadioGroup] requires a
  /// non-null callback, so a no-op is supplied only as that adapter.
  final ValueChanged<T?>? onChanged;

  /// Whether the group is enabled.
  ///
  /// Combined with [onChanged] != null to produce the interactive state.
  final bool enabled;

  /// Accessible name for the radio group.
  final String? semanticLabel;

  /// Radios that participate in this group.
  final Widget child;

  bool get _interactive => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    Widget group = RadioGroup<T>(
      groupValue: groupValue,
      onChanged: onChanged ?? _disabledRadioGroupOnChanged,
      child: NakedRadioGroupScope<T>(enabled: _interactive, child: child),
    );

    final label = semanticLabel;
    if (label != null && label.isNotEmpty) {
      // No role here: Flutter's RadioGroup already publishes the single
      // SemanticsRole.radioGroup node (radio_group.dart), and it accepts no
      // label. Adding the role again would announce the group twice, so the
      // label lives on a plain container around Flutter's role node.
      group = Semantics(
        container: true,
        explicitChildNodes: true,
        label: label,
        child: group,
      );
    }

    return group;
  }
}

void _disabledRadioGroupOnChanged<T>(T? _) {}

/// Enabled state published by [NakedRadioGroup].
///
/// Typed by the group's value type so the lookup stays aligned with
/// Flutter's typed [RadioGroup.maybeOf] registry lookup under nested
/// groups of different value types.
class NakedRadioGroupScope<T> extends InheritedWidget {
  /// Creates a group-enabled scope.
  const NakedRadioGroupScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  /// Whether radios in this group are interactive.
  final bool enabled;

  /// The nearest group scope for value type [T], if any.
  static NakedRadioGroupScope<T>? maybeOf<T>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NakedRadioGroupScope<T>>();
  }

  @override
  bool updateShouldNotify(NakedRadioGroupScope<T> oldWidget) {
    return enabled != oldWidget.enabled;
  }
}
