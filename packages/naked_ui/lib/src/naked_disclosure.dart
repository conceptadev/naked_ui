import 'dart:async';

import 'package:flutter/widgets.dart';

import 'mixins/naked_mixins.dart';
import 'utilities/intents.dart';
import 'utilities/naked_focusable_detector.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/state.dart';

/// Builds a transition around a disclosure panel.
///
/// The [animation] runs from zero to one while the panel opens and from one to
/// zero while it closes. The real panel remains mounted until the closing
/// animation is dismissed.
typedef NakedDisclosureTransitionBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> animation,
      Widget child,
    );

/// Immutable view passed to [NakedDisclosure.builder] and
/// [NakedDisclosure.itemBuilder].
class NakedDisclosureState extends NakedState {
  /// Creates an immutable disclosure state snapshot.
  NakedDisclosureState({required super.states, required this.isExpanded});

  /// Whether the disclosure panel is expanded.
  final bool isExpanded;

  /// Returns the nearest [NakedDisclosureState] provided by
  /// [NakedStateScope].
  static NakedDisclosureState of(BuildContext context) =>
      NakedState.of(context);

  /// Returns the nearest [NakedDisclosureState], if one is available.
  static NakedDisclosureState? maybeOf(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest state scope.
  static WidgetStatesController controllerOf(BuildContext context) =>
      NakedState.controllerOf<NakedDisclosureState>(context);

  /// Returns the nearest state scope's controller, if one is available.
  static WidgetStatesController? maybeControllerOf(BuildContext context) =>
      NakedState.maybeControllerOf<NakedDisclosureState>(context);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedDisclosureState &&
        other.isExpanded == isExpanded &&
        statesEqual(other);
  }

  @override
  int get hashCode => Object.hash(statesHashCode, isExpanded);
}

/// A headless disclosure button controlling one content panel.
///
/// When [expanded] is null, the disclosure owns its expansion state and starts
/// from [defaultExpanded]. When [expanded] is non-null, activation requests a
/// new value through [onExpandedChanged] and the owner remains the source of
/// truth.
///
/// The [builder] decorates the optional static [child]. The [itemBuilder]
/// decorates the complete trigger-and-panel item without changing the trigger
/// hit target.
class NakedDisclosure extends StatefulWidget {
  /// Creates a headless disclosure.
  const NakedDisclosure({
    super.key,
    this.child,
    this.builder,
    required this.panel,
    this.itemBuilder,
    this.expanded,
    this.defaultExpanded = false,
    this.onExpandedChanged,
    this.enabled = true,
    this.mouseCursor = SystemMouseCursors.click,
    this.enableFeedback = true,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.onHoverChange,
    this.onPressChange,
    this.semanticLabel,
    this.semanticHint,
    this.excludeSemantics = false,
    this.transitionBuilder,
    this.animationStyle = const AnimationStyle(
      curve: Curves.ease,
      duration: Duration(milliseconds: 200),
      reverseDuration: Duration(milliseconds: 200),
    ),
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided.',
       );

  /// Static content supplied to [builder], or used directly as the trigger.
  final Widget? child;

  /// Builds the trigger using the current [NakedDisclosureState].
  final ValueWidgetBuilder<NakedDisclosureState>? builder;

  /// Content controlled by the disclosure trigger.
  final Widget panel;

  /// Builds a presentation wrapper around the assembled trigger and panel.
  ///
  /// The callback context is below the disclosure state scope. The supplied
  /// child must remain in the returned subtree to preserve behavior.
  final ValueWidgetBuilder<NakedDisclosureState>? itemBuilder;

  /// Whether the panel is expanded when controlled, or null when uncontrolled.
  final bool? expanded;

  /// Initial expansion for an uncontrolled disclosure.
  ///
  /// Changes after initialization are ignored.
  final bool defaultExpanded;

  /// Called when activation requests an expansion change.
  final ValueChanged<bool>? onExpandedChanged;

  /// Whether disclosure-trigger interaction is enabled.
  final bool enabled;

  /// Mouse cursor used while the trigger is interactive.
  final MouseCursor mouseCursor;

  /// Whether activation provides platform feedback.
  final bool enableFeedback;

  /// Focus node associated with the trigger.
  final FocusNode? focusNode;

  /// Whether the trigger requests focus when first built.
  final bool autofocus;

  /// Called when trigger focus changes.
  final ValueChanged<bool>? onFocusChange;

  /// Called when trigger hover changes.
  final ValueChanged<bool>? onHoverChange;

  /// Called when trigger press state changes.
  final ValueChanged<bool>? onPressChange;

  /// Accessible name that replaces trigger-descendant semantics when non-empty.
  final String? semanticLabel;

  /// Additional context announced with the trigger's accessible name.
  final String? semanticHint;

  /// Whether to hide the trigger and panel from the semantics tree.
  final bool excludeSemantics;

  /// Optional transition applied to the panel.
  ///
  /// Without a transition builder, expansion and collapse are immediate.
  final NakedDisclosureTransitionBuilder? transitionBuilder;

  /// Curves and durations used by [transitionBuilder].
  final AnimationStyle animationStyle;

  @override
  State<NakedDisclosure> createState() => _NakedDisclosureState();
}

class _NakedDisclosureState extends State<NakedDisclosure>
    with
        WidgetStatesMixin<NakedDisclosure>,
        FocusNodeMixin<NakedDisclosure>,
        SingleTickerProviderStateMixin<NakedDisclosure> {
  static int _nextPanelSemanticsIdentifier = 0;

  Timer? _keyboardPressTimer;
  late final String _panelSemanticsIdentifier =
      'naked-disclosure-panel-${_nextPanelSemanticsIdentifier++}';
  final FocusNode _panelFocusNode = FocusNode(
    debugLabel: 'NakedDisclosure panel',
  );
  late final AnimationController _animationController;
  late CurvedAnimation _animation;
  late bool _uncontrolledExpanded;
  late bool _panelMounted;
  bool _animationsDisabled = false;
  int _transitionGeneration = 0;

  bool get _isControlled => widget.expanded != null;

  bool get _isExpanded => widget.expanded ?? _uncontrolledExpanded;

  bool get _isInteractive =>
      widget.enabled && (!_isControlled || widget.onExpandedChanged != null);

  bool get _shouldAnimate =>
      widget.transitionBuilder != null &&
      widget.animationStyle != AnimationStyle.noAnimation &&
      !_animationsDisabled;

  Duration get _forwardDuration =>
      widget.animationStyle.duration ?? const Duration(milliseconds: 200);

  Duration get _reverseDuration =>
      widget.animationStyle.reverseDuration ??
      const Duration(milliseconds: 200);

  Curve get _forwardCurve => widget.animationStyle.curve ?? Curves.ease;

  Curve get _reverseCurve =>
      widget.animationStyle.reverseCurve ?? _forwardCurve.flipped;

  @override
  FocusNode? get widgetProvidedNode => widget.focusNode;

  @override
  void initializeWidgetStates() {
    updateDisabledState(!_isInteractive);
    updateSelectedState(_isExpanded, null);
  }

  @override
  void initState() {
    // WidgetStatesMixin initializes state from _isExpanded in super.initState.
    _uncontrolledExpanded = widget.defaultExpanded;
    _panelMounted = _isExpanded;
    super.initState();
    _animationController = AnimationController(
      value: _isExpanded ? 1 : 0,
      duration: _forwardDuration,
      reverseDuration: _reverseDuration,
      vsync: this,
    );
    _animation = _createAnimation();
  }

  CurvedAnimation _createAnimation() => CurvedAnimation(
    parent: _animationController,
    curve: _forwardCurve,
    reverseCurve: _reverseCurve,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_animationsDisabled == animationsDisabled) return;
    _animationsDisabled = animationsDisabled;
    _applyExpansion();
  }

  @override
  void didUpdateWidget(covariant NakedDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldExpanded = oldWidget.expanded ?? _uncontrolledExpanded;

    if (oldWidget.expanded != null && widget.expanded == null) {
      _uncontrolledExpanded = oldWidget.expanded!;
    }

    if (widget.animationStyle != oldWidget.animationStyle) {
      _animationController
        ..duration = _forwardDuration
        ..reverseDuration = _reverseDuration;
      _animation.dispose();
      _animation = _createAnimation();
    }

    final interactionChanged =
        oldWidget.enabled != widget.enabled ||
        oldWidget.expanded != widget.expanded ||
        oldWidget.onExpandedChanged != widget.onExpandedChanged;
    if (interactionChanged) {
      updateDisabledState(!_isInteractive);
      if (!_isInteractive) {
        _cleanupKeyboardPress();
        updatePressState(false, widget.onPressChange);
      }
    }

    updateSelectedState(_isExpanded, null);
    if (oldExpanded != _isExpanded ||
        oldWidget.transitionBuilder != widget.transitionBuilder ||
        oldWidget.animationStyle != widget.animationStyle) {
      _applyExpansion();
    }
  }

  void _cleanupKeyboardPress() {
    _keyboardPressTimer?.cancel();
    _keyboardPressTimer = null;
  }

  void _requestToggle() {
    if (!_isInteractive) return;
    final nextExpanded = !_isExpanded;

    if (!_isControlled) {
      _uncontrolledExpanded = nextExpanded;
      updateSelectedState(nextExpanded, null);
      _applyExpansion();
    }

    widget.onExpandedChanged?.call(nextExpanded);
  }

  void _handleTap() {
    if (!_isInteractive) return;
    if (widget.enableFeedback) Feedback.forTap(context);
    _requestToggle();
  }

  void _handleKeyboardActivation() {
    if (!_isInteractive) return;
    if (widget.enableFeedback) Feedback.forTap(context);
    _requestToggle();
    updatePressState(true, widget.onPressChange);
    _cleanupKeyboardPress();
    _keyboardPressTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) updatePressState(false, widget.onPressChange);
      _keyboardPressTimer = null;
    });
  }

  void _applyExpansion() {
    final generation = ++_transitionGeneration;
    if (!_isExpanded && _panelFocusNode.hasFocus) {
      if (_isInteractive) {
        requestEffectiveFocus();
      } else {
        _panelFocusNode.unfocus();
      }
    }

    if (!_shouldAnimate) {
      _animationController
        ..stop()
        ..value = _isExpanded ? 1 : 0;
      _panelMounted = _isExpanded;

      return;
    }

    if (_isExpanded) {
      _panelMounted = true;
      _animationController.forward();

      return;
    }

    unawaited(_reverseAndUnmount(generation));
  }

  Future<void> _reverseAndUnmount(int generation) async {
    await _animationController.reverse();
    if (!mounted || generation != _transitionGeneration || _isExpanded) {
      return;
    }
    setState(() => _panelMounted = false);
  }

  Widget _buildPanel(BuildContext context) {
    final panelHidden = !_isExpanded;
    final panel = Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: _panelSemanticsIdentifier,
      child: Focus(
        focusNode: _panelFocusNode,
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        child: widget.panel,
      ),
    );
    final transitionBuilder = widget.transitionBuilder;
    final transitionedPanel = transitionBuilder == null
        ? panel
        : transitionBuilder(context, _animation, panel);

    return ExcludeSemantics(
      excluding: panelHidden,
      child: IgnorePointer(
        ignoring: panelHidden,
        child: ExcludeFocusTraversal(
          excluding: panelHidden,
          child: ExcludeFocus(excluding: panelHidden, child: transitionedPanel),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cleanupKeyboardPress();
    _panelFocusNode.dispose();
    _animation.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disclosureState = NakedDisclosureState(
      states: widgetStates,
      isExpanded: _isExpanded,
    );

    final scopedItem = NakedStateScope<NakedDisclosureState>(
      value: disclosureState,
      child: Builder(
        builder: (context) {
          final trigger =
              widget.builder?.call(context, disclosureState, widget.child) ??
              widget.child!;
          final semanticLabel = widget.semanticLabel;
          final hasReplacementLabel = semanticLabel?.trim().isNotEmpty ?? false;
          final triggerContent = GestureDetector(
            onTapDown: _isInteractive
                ? (_) => updatePressState(true, widget.onPressChange)
                : null,
            onTapUp: _isInteractive
                ? (_) => updatePressState(false, widget.onPressChange)
                : null,
            onTap: _isInteractive ? _handleTap : null,
            onTapCancel: _isInteractive
                ? () => updatePressState(false, widget.onPressChange)
                : null,
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            child: trigger,
          );

          final semanticTrigger = Semantics(
            enabled: _isInteractive,
            button: true,
            expanded: _isExpanded,
            controlsNodes: _isExpanded ? {_panelSemanticsIdentifier} : null,
            label: hasReplacementLabel ? semanticLabel : null,
            hint: widget.semanticHint,
            excludeSemantics: hasReplacementLabel,
            onTap: _isInteractive ? _handleTap : null,
            child: triggerContent,
          );

          final focusableTrigger = NakedFocusableDetector(
            enabled: _isInteractive,
            autofocus: widget.autofocus,
            onFocusChange: (focused) =>
                updateFocusState(focused, widget.onFocusChange),
            onHoverChange: (hovered) =>
                updateHoverState(hovered, widget.onHoverChange),
            focusNode: effectiveFocusNode,
            mouseCursor: _isInteractive
                ? widget.mouseCursor
                : SystemMouseCursors.basic,
            shortcuts: NakedIntentActions.button.shortcuts,
            actions: NakedIntentActions.button.actions(
              onPressed: _handleKeyboardActivation,
            ),
            child: semanticTrigger,
          );

          final children = <Widget>[focusableTrigger];
          if (_panelMounted) children.add(_buildPanel(context));
          final assembledItem = Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          );
          final itemBuilder = widget.itemBuilder;

          return itemBuilder == null
              ? assembledItem
              : itemBuilder(context, disclosureState, assembledItem);
        },
      ),
    );

    return ExcludeSemantics(
      excluding: widget.excludeSemantics,
      child: scopedItem,
    );
  }
}
