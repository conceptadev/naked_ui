import 'package:flutter/foundation.dart' show Listenable, defaultTargetPlatform;
import 'package:flutter/gestures.dart';
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
    this.restoreHoverOnEnable = false,
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

  /// Whether to restore hover after re-enabling under a stationary pointer.
  ///
  /// This is opt-in so existing component hover behavior remains unchanged.
  final bool restoreHoverOnEnable;

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
  bool _pointerInside = false;
  bool _hoverReported = false;

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

  void _handlePointerEnter(PointerEnterEvent event) {
    _pointerInside = true;
    if (widget.enabled) _reportHover(true);
  }

  void _handlePointerExit(PointerExitEvent event) {
    _pointerInside = false;
    if (widget.enabled) _reportHover(false);
  }

  void _reportHover(bool hovered) {
    if (_hoverReported == hovered) return;
    _hoverReported = hovered;
    widget.onHoverChange?.call(hovered);
  }

  void _restoreHoverAfterFrame() {
    if (!_pointerInside || widget.onHoverChange == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.enabled &&
          widget.restoreHoverOnEnable &&
          _pointerInside) {
        _reportHover(true);
      }
    });
  }

  void _clearHoverAfterFrame() {
    if (!_hoverReported) return;
    _hoverReported = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onHoverChange?.call(false);
    });
  }

  @override
  void didUpdateWidget(NakedFocusableDetector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enabled != oldWidget.enabled) {
      _handleEnabledChange();
      if (widget.restoreHoverOnEnable) {
        if (widget.enabled) {
          _restoreHoverAfterFrame();
        } else {
          _clearHoverAfterFrame();
        }
      }
    }

    if ((!widget.restoreHoverOnEnable && oldWidget.restoreHoverOnEnable) ||
        (widget.onHoverChange == null && oldWidget.onHoverChange != null)) {
      _pointerInside = false;
      _hoverReported = false;
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

    // Focus derives these values from a cached FocusNode snapshot. The custom
    // semantics wrapper reads the current node and its ancestors instead.
    final focusChild = widget.includeSemantics
        ? _NakedFocusSemantics(
            canRequestFocus: effectiveCanRequestFocus,
            child: widget.child,
          )
        : widget.child;

    // Start with Focus wrapping the child.
    Widget result = Focus(
      focusNode: effectiveFocusNode,
      autofocus: widget.autofocus,
      onFocusChange: widget.onFocusChange,
      onKeyEvent: widget.onKeyEvent,

      canRequestFocus: effectiveCanRequestFocus,
      skipTraversal: widget.skipTraversal,
      descendantsAreFocusable: widget.descendantsAreFocusable,
      descendantsAreTraversable: widget.descendantsAreTraversable,
      includeSemantics: false,
      child: focusChild,
    );

    // Wrap with MouseRegion if hover detection is needed
    if (widget.onHoverChange != null) {
      void Function(PointerEnterEvent)? onEnter;
      void Function(PointerExitEvent)? onExit;
      if (widget.restoreHoverOnEnable) {
        onEnter = _handlePointerEnter;
        onExit = _handlePointerExit;
      } else if (widget.enabled) {
        onEnter = (_) => widget.onHoverChange!(true);
        onExit = (_) => widget.onHoverChange!(false);
      }

      result = MouseRegion(
        onEnter: onEnter,
        onExit: onExit,
        cursor: widget.mouseCursor ?? MouseCursor.defer,
        child: result,
      );
    }

    // Keep the wrapper stable across enabled changes so stateful descendants
    // are not recreated. An empty map disables local actions.
    if (widget.actions != null && widget.actions!.isNotEmpty) {
      result = Actions(
        actions: widget.enabled
            ? widget.actions!
            : const <Type, Action<Intent>>{},
        child: result,
      );
    }

    // Add Shortcuts last (outermost). An empty map disables local shortcuts
    // without changing the widget-tree shape.
    if (widget.shortcuts != null && widget.shortcuts!.isNotEmpty) {
      result = Shortcuts(
        shortcuts: widget.enabled
            ? widget.shortcuts!
            : const <ShortcutActivator, Intent>{},
        child: result,
      );
    }

    return result;
  }
}

class _NakedFocusSemantics extends StatelessWidget {
  const _NakedFocusSemantics({
    required this.canRequestFocus,
    required this.child,
  });

  final bool canRequestFocus;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final focusNode = Focus.of(context);
    final focusChain = Listenable.merge(<Listenable>[
      focusNode,
      ...focusNode.ancestors,
    ]);

    return ListenableBuilder(
      listenable: focusChain,
      builder: (context, child) {
        final effectiveCanRequestFocus =
            canRequestFocus && focusNode.canRequestFocus;
        return Semantics(
          onFocus:
              defaultTargetPlatform != TargetPlatform.iOS &&
                  effectiveCanRequestFocus
              ? focusNode.requestFocus
              : null,
          focusable: effectiveCanRequestFocus,
          focused: effectiveCanRequestFocus ? focusNode.hasPrimaryFocus : null,
          child: child,
        );
      },
      child: child,
    );
  }
}
