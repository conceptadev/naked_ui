import 'dart:async';

import 'package:flutter/widgets.dart';

import 'mixins/naked_mixins.dart';
import 'utilities/intents.dart';
import 'utilities/naked_focusable_detector.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/state.dart';

/// Immutable view passed to [NakedButton.builder].
class NakedButtonState extends NakedState {
  /// Creates an immutable snapshot of button interaction [states].
  NakedButtonState({required super.states});

  /// Returns the nearest [NakedButtonState] provided by [NakedStateScope].
  static NakedButtonState of(BuildContext context) => NakedState.of(context);

  /// Returns the nearest [NakedButtonState], if one is available.
  static NakedButtonState? maybeOf(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest state scope.
  static WidgetStatesController controllerOf(BuildContext context) =>
      NakedState.controllerOf<NakedButtonState>(context);

  /// Returns the nearest state scope's controller, if one is available.
  static WidgetStatesController? maybeControllerOf(BuildContext context) =>
      NakedState.maybeControllerOf<NakedButtonState>(context);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedButtonState && statesEqual(other);
  }

  @override
  int get hashCode => statesHashCode;
}

/// A headless button without visuals that provides interaction states.
///
/// The [builder] receives a [NakedButtonState] with interaction states.
///
/// See also:
/// - [GestureDetector], for direct gesture handling without button semantics.
class NakedButton extends StatefulWidget {
  /// Creates a headless button.
  const NakedButton({
    super.key,
    this.child,
    this.onPressed,
    this.onLongPress,
    this.enabled = true,
    this.mouseCursor = SystemMouseCursors.click,
    this.enableFeedback = true,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.onHoverChange,
    this.onPressChange,
    this.builder,
    this.focusOnPress = false,
    this.tooltip,
    this.semanticLabel,
    this.semanticHint,
    this.excludeSemantics = false,
  });

  /// The button content.
  final Widget? child;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// Called when the button is long-pressed.
  final VoidCallback? onLongPress;

  /// Called when focus changes.
  final ValueChanged<bool>? onFocusChange;

  /// Called when hover changes.
  final ValueChanged<bool>? onHoverChange;

  /// Called when the pressed state changes.
  final ValueChanged<bool>? onPressChange;

  /// Builds the button using the current [NakedButtonState].
  final ValueWidgetBuilder<NakedButtonState>? builder;

  /// Whether the button is interactive.
  final bool enabled;

  /// The mouse cursor when enabled.
  final MouseCursor mouseCursor;

  /// Whether to provide haptic feedback on interactions.
  final bool enableFeedback;

  /// The focus node for the button.
  final FocusNode? focusNode;

  /// Whether to autofocus.
  final bool autofocus;

  /// Whether to request focus when pressed.
  final bool focusOnPress;

  /// Tooltip text for accessibility.
  final String? tooltip;

  /// Semantic label for the button.
  final String? semanticLabel;

  /// Additional context announced with the button's accessible name.
  ///
  /// Lives on the same Semantics node as the button role, label, enabled
  /// state, and tap/long-press actions. Do not wrap the button in another
  /// Semantics node just to attach a hint.
  final String? semanticHint;

  /// Whether to exclude this widget from the semantic tree.
  ///
  /// When true, the widget and its children are hidden from accessibility services.
  final bool excludeSemantics;

  @override
  State<NakedButton> createState() => _NakedButtonState();
}

class _NakedButtonState extends State<NakedButton>
    with WidgetStatesMixin<NakedButton>, FocusNodeMixin<NakedButton> {
  Timer? _keyboardPressTimer;

  // Simple derived state - no over-engineering
  bool get _isInteractive =>
      widget.enabled &&
      (widget.onPressed != null || widget.onLongPress != null);

  @override
  FocusNode? get widgetProvidedNode => widget.focusNode;

  void _cleanupKeyboardTimer() {
    _keyboardPressTimer?.cancel();
    _keyboardPressTimer = null;
  }

  void _handleKeyboardActivation() {
    if (!widget.enabled || widget.onPressed == null) return;

    if (widget.enableFeedback) {
      Feedback.forTap(context);
    }

    widget.onPressed!();

    // Visual feedback for keyboard activation
    updatePressState(true, widget.onPressChange);

    _cleanupKeyboardTimer();
    _keyboardPressTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        updatePressState(false, widget.onPressChange);
      }
      _keyboardPressTimer = null;
    });
  }

  void _handleTap() {
    if (!widget.enabled || widget.onPressed == null) return;

    if (widget.enableFeedback) {
      Feedback.forTap(context);
    }
    widget.onPressed!();
  }

  void _handleLongPress() {
    if (!widget.enabled) return;

    if (widget.enableFeedback && widget.onLongPress != null) {
      Feedback.forLongPress(context);
    }

    // Only call user's handler if they provided one
    widget.onLongPress?.call();
  }

  void _onPressStart(TapDownDetails details) {
    if (widget.focusOnPress) {
      requestEffectiveFocus();
    }
    updatePressState(true, widget.onPressChange);
  }

  void _onPressEnd() {
    updatePressState(false, widget.onPressChange);
  }

  @override
  void initializeWidgetStates() {
    // Set initial disabled state based on interactive state
    updateDisabledState(!_isInteractive);
  }

  @override
  void didUpdateWidget(covariant NakedButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only update if interactive state actually changed
    final wasInteractive =
        oldWidget.enabled &&
        (oldWidget.onPressed != null || oldWidget.onLongPress != null);

    if (wasInteractive != _isInteractive) {
      updateDisabledState(!_isInteractive);

      // Clean up if becoming non-interactive
      if (!_isInteractive) {
        _cleanupKeyboardTimer();
        // Force clear pressed state when disabled
        updatePressState(false, widget.onPressChange);
      }
    }
  }

  @override
  void dispose() {
    _cleanupKeyboardTimer();
    super.dispose(); // Mixins handle their cleanup
  }

  @override
  Widget build(BuildContext context) {
    final buttonState = NakedButtonState(states: widgetStates);

    Widget gestureDetector = GestureDetector(
      onTapDown: _isInteractive ? _onPressStart : null,
      onTapUp: _isInteractive ? (_) => _onPressEnd() : null,
      onTap: _isInteractive ? _handleTap : null,
      onTapCancel: _isInteractive ? _onPressEnd : null,
      onLongPress: _isInteractive ? _handleLongPress : null,
      onLongPressStart: _isInteractive
          ? (details) => updatePressState(true, widget.onPressChange)
          : null,
      onLongPressEnd: _isInteractive ? (_) => _onPressEnd() : null,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      child: NakedStateScopeBuilder(
        value: buttonState,
        child: widget.child,
        builder: widget.builder,
      ),
    );

    Widget result = widget.excludeSemantics
        ? ExcludeSemantics(child: gestureDetector)
        : Semantics(
            enabled: _isInteractive,
            button: true,
            label: widget.semanticLabel,
            hint: widget.semanticHint,
            tooltip: widget.tooltip,
            onTap: widget.onPressed != null ? _handleTap : null,
            onLongPress: widget.onLongPress != null ? _handleLongPress : null,
            child: gestureDetector,
          );

    return NakedFocusableDetector(
      enabled: _isInteractive,
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        updateFocusState(focused, widget.onFocusChange);
      },
      onHoverChange: (hovered) {
        updateHoverState(hovered, widget.onHoverChange);
      },
      focusNode: effectiveFocusNode,
      mouseCursor: _isInteractive
          ? widget.mouseCursor
          : SystemMouseCursors.basic,
      shortcuts: NakedIntentActions.button.shortcuts,
      actions: NakedIntentActions.button.actions(
        onPressed: _handleKeyboardActivation,
      ),
      child: result,
    );
  }
}
