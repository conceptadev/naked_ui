import 'package:flutter/material.dart';

import '../mixins/naked_mixins.dart';

/// Minimal widget that composes [MouseRegion], [Focus], [Shortcuts], and [Actions]
/// based on what's needed. Exposes all [Focus] parameters for full control.
class NakedFocusableDetector extends StatefulWidget {
  /// Creates an interaction detector around [child].
  const NakedFocusableDetector({
    super.key,
    required this.child,
    this.enabled = true,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.descendantsAreFocusable = true,
    this.descendantsAreTraversable = true,
    this.skipTraversal = false,
    this.includeSemantics = true,
    this.onFocusChange,
    this.onHoverChange,
    this.onEnableChange,
    this.onKeyEvent,

    this.focusNode,
    this.mouseCursor,
    this.shortcuts,
    this.actions,
    this.debugLabel,
  });

  /// The widget to wrap with interaction detection.
  final Widget child;

  /// Whether this widget is enabled for interaction.
  final bool enabled;

  /// Whether to autofocus when first built.
  final bool autofocus;

  /// Whether this node can request focus.
  final bool canRequestFocus;

  /// Whether descendants can receive focus.
  final bool descendantsAreFocusable;

  /// Whether descendants are traversable.
  final bool descendantsAreTraversable;

  /// Whether to skip in traversal order.
  final bool skipTraversal;

  /// Whether to include focus semantics.
  final bool includeSemantics;

  /// Called when the focus state changes.
  final ValueChanged<bool>? onFocusChange;

  /// Called when the hover state changes. Adds a [MouseRegion] when provided.
  final ValueChanged<bool>? onHoverChange;

  /// Called when the enabled state changes.
  final ValueChanged<bool>? onEnableChange;

  /// Raw keyboard event handler.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Mouse cursor. Used only when [onHoverChange] is provided.
  final MouseCursor? mouseCursor;

  /// Keyboard shortcuts. Applied only when provided and enabled.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// Intent actions. Applied only when provided and enabled.
  final Map<Type, Action<Intent>>? actions;

  /// Debug label for the focus node.
  final String? debugLabel;

  @override
  State<NakedFocusableDetector> createState() => _NakedFocusableDetectorState();
}

class _NakedFocusableDetectorState extends State<NakedFocusableDetector>
    with FocusNodeMixin<NakedFocusableDetector> {
  bool _wasEnabled = true;

  @override
  FocusNode? get widgetProvidedNode => widget.focusNode;

  @override
  String get focusNodeDebugLabel =>
      widget.debugLabel ?? 'NakedFocusableDetector';

  @override
  void initState() {
    super.initState();
    _wasEnabled = widget.enabled;
  }

  void _handleEnabledChange() {
    if (widget.onEnableChange != null && widget.enabled != _wasEnabled) {
      widget.onEnableChange!(widget.enabled);
    }
    _wasEnabled = widget.enabled;
  }

  @override
  void didUpdateWidget(NakedFocusableDetector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enabled != oldWidget.enabled) {
      _handleEnabledChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check navigation mode to determine focus behavior.
    final navigationMode =
        MediaQuery.maybeNavigationModeOf(context) ?? NavigationMode.traditional;
    final effectiveCanRequestFocus =
        navigationMode == NavigationMode.directional
        // Directional: disabled widgets stay traversable.
        ? widget.canRequestFocus
        // Traditional: disabled = unfocusable.
        : widget.enabled && widget.canRequestFocus;

    // Start with Focus wrapping the child
    Widget result = Focus(
      focusNode: effectiveFocusNode,
      autofocus: widget.autofocus,
      onFocusChange: widget.onFocusChange,
      onKeyEvent: widget.onKeyEvent,

      canRequestFocus: effectiveCanRequestFocus,
      skipTraversal: widget.skipTraversal,
      descendantsAreFocusable: widget.descendantsAreFocusable,
      descendantsAreTraversable: widget.descendantsAreTraversable,
      includeSemantics: widget.includeSemantics,
      child: widget.child,
    );

    // Wrap with MouseRegion if hover detection is needed
    // When disabled, MouseRegion still exists (for cursor) but doesn't trigger callbacks
    if (widget.onHoverChange != null) {
      result = MouseRegion(
        onEnter: widget.enabled ? (_) => widget.onHoverChange!(true) : null,
        onExit: widget.enabled ? (_) => widget.onHoverChange!(false) : null,
        cursor: widget.mouseCursor ?? MouseCursor.defer,
        child: result,
      );
    }

    // Add Actions if provided and enabled
    if (widget.enabled &&
        widget.actions != null &&
        widget.actions!.isNotEmpty) {
      result = Actions(actions: widget.actions!, child: result);
    }

    // Add Shortcuts last (outermost) if provided and enabled
    if (widget.enabled &&
        widget.shortcuts != null &&
        widget.shortcuts!.isNotEmpty) {
      result = Shortcuts(shortcuts: widget.shortcuts!, child: result);
    }

    return result;
  }
}
