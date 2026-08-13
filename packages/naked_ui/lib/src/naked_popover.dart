import 'dart:async';

import 'package:flutter/widgets.dart';

import 'mixins/naked_mixins.dart';
import 'naked_button.dart';
import 'utilities/anchored_overlay_shell.dart';
import 'utilities/intents.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/positioning.dart';
import 'utilities/state.dart';

/// Immutable view passed to [NakedPopover.builder].
class NakedPopoverState extends NakedState {
  /// Whether the overlay is currently open.
  final bool isOpen;

  /// Creates an immutable snapshot of popover interaction state.
  NakedPopoverState({required super.states, required this.isOpen});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedPopoverState &&
        statesEqual(other) &&
        other.isOpen == isOpen;
  }

  @override
  int get hashCode => Object.hash(statesHashCode, isOpen);

  /// Returns the nearest [NakedPopoverState] provided by [NakedStateScope].
  static NakedPopoverState of(BuildContext context) => NakedState.of(context);

  /// Returns the nearest [NakedPopoverState] if available.
  static NakedPopoverState? maybeOf(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf(BuildContext context) =>
      NakedState.controllerOf<NakedPopoverState>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf(BuildContext context) =>
      NakedState.maybeControllerOf<NakedPopoverState>(context);
}

/// A headless popover without visuals.
///
/// Provides toggleable overlay functionality with custom content rendering.
/// Handles tap interactions, positioning, and focus management.
///
/// ```dart
/// // Static trigger
/// NakedPopover(
///   popoverBuilder: (context, info) => Container(
///     padding: EdgeInsets.all(16),
///     child: Text('Popover content'),
///   ),
///   child: Text('Click me'),
/// )
///
/// // Dynamic trigger with state
/// NakedPopover(
///   popoverBuilder: (context, info) => Container(
///     padding: EdgeInsets.all(16),
///     child: Text('Popover content'),
///   ),
///   builder: (context, state, child) => Container(
///     color: state.isPressed ? Colors.blue : Colors.grey,
///     child: Text('Click me'),
///   ),
/// )
/// ```
///
/// See also:
/// - [NakedMenu], for dropdown menu functionality.
/// - [NakedTooltip], for hover-triggered lightweight hints.
/// - [NakedDialog], for modal dialog functionality.
class NakedPopover extends StatefulWidget {
  /// Creates a headless popover with a custom overlay builder.
  const NakedPopover({
    super.key,
    this.child,
    this.builder,
    required this.popoverBuilder,
    this.positioning = const OverlayPositionConfig(),
    this.consumeOutsideTaps = true,
    this.useRootOverlay = false,
    this.openOnTap = true,
    this.anchorKey,
    this.triggerFocusNode,
    this.onOpen,
    this.onClose,
    this.onOpenRequested,
    this.onCloseRequested,
    this.controller,
    this.semanticLabel,
    this.excludeSemantics = false,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       );

  /// The static trigger widget.
  final Widget? child;

  /// Builds the trigger surface.
  final ValueWidgetBuilder<NakedPopoverState>? builder;

  /// The builder for popover content.
  final RawMenuAnchorOverlayBuilder popoverBuilder;

  /// Positioning configuration for the overlay.
  final OverlayPositionConfig positioning;

  /// Whether to consume taps outside the overlay.
  final bool consumeOutsideTaps;

  /// Whether to use the root overlay.
  final bool useRootOverlay;

  /// Whether tapping the trigger opens the popover.
  final bool openOnTap;

  /// Optional key for a separate widget used as the positioning anchor.
  ///
  /// When null, the trigger is the anchor. The keyed widget may be a sibling
  /// or ancestor descendant in the same overlay subtree, allowing trigger and
  /// positioning geometry to be composed independently.
  final GlobalKey? anchorKey;

  /// Focus node for the trigger widget.
  final FocusNode? triggerFocusNode;

  /// Called when the popover opens.
  final VoidCallback? onOpen;

  /// Called when the popover closes.
  final VoidCallback? onClose;

  /// Controls whether the popover overlay is open.
  final MenuController? controller;

  /// Optional semantics label for the trigger.
  final String? semanticLabel;

  /// Whether to hide the popover trigger subtree from accessibility.
  final bool excludeSemantics;

  /// Called when a request is made to open the popover.
  ///
  /// This callback allows you to customize the opening behavior, such as
  /// adding animations or delays. Call `showOverlay` to actually show the popover.
  final RawMenuAnchorOpenRequestedCallback? onOpenRequested;

  /// Called when a request is made to close the popover.
  ///
  /// This callback allows you to customize the closing behavior, such as
  /// adding animations or delays. Call `hideOverlay` to actually hide the popover.
  final RawMenuAnchorCloseRequestedCallback? onCloseRequested;

  @override
  State<NakedPopover> createState() => _NakedPopoverState();
}

class _NakedPopoverState extends State<NakedPopover>
    with WidgetStatesMixin<NakedPopover> {
  // ignore: dispose-fields
  final _internalMenuController = MenuController();

  // Internal node used when the child does not already provide a Focus.
  final _internalTriggerNode = FocusNode(
    debugLabel: 'NakedPopover trigger (internal)',
  );
  FocusNode? _observedChildFocusNode;
  Timer? _keyboardPressTimer;

  MenuController get _menuController =>
      widget.controller ?? _internalMenuController;

  @override
  void initState() {
    super.initState();
    _updateObservedChildFocusNode();
  }

  void _toggle() {
    if (_menuController.isOpen) {
      _menuController.close();
    } else {
      _menuController.open();
    }
  }

  void _handleOpen() {
    if (mounted) setState(() {});
    widget.onOpen?.call();
  }

  void _handleClose() {
    if (mounted) setState(() {});
    widget.onClose?.call();
  }

  /// If the child is a Focus widget, extract its node so we can return focus to it.
  FocusNode? _extractChildFocusNode() {
    final c = widget.child;
    if (c is Focus) return c.focusNode;

    return null;
  }

  void _updateObservedChildFocusNode() {
    final next = _extractChildFocusNode();
    if (identical(next, _observedChildFocusNode)) return;
    _observedChildFocusNode?.removeListener(_handleChildFocusChange);
    _observedChildFocusNode = next;
    _observedChildFocusNode?.addListener(_handleChildFocusChange);
    _handleChildFocusChange();
  }

  void _handleChildFocusChange() {
    updateFocusState(_observedChildFocusNode?.hasFocus ?? false, null);
  }

  void _activate() {
    Feedback.forTap(context);
    _toggle();
  }

  void _handleKeyboardActivation() {
    _keyboardPressTimer?.cancel();
    _activate();
    updatePressState(true, null);
    _keyboardPressTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) updatePressState(false, null);
      _keyboardPressTimer = null;
    });
  }

  Widget _buildChildOwnedTrigger(FocusNode childFocusNode) {
    final state = NakedPopoverState(
      states: {
        ...widgetStates,
        if (childFocusNode.hasFocus) WidgetState.focused,
      },
      isOpen: _menuController.isOpen,
    );
    final content = NakedStateScopeBuilder(
      value: state,
      child: widget.child,
      builder: widget.builder,
    );
    final semanticContent = widget.semanticLabel == null
        ? content
        : ExcludeSemantics(child: content);

    Widget trigger = GestureDetector(
      onTapDown: (_) => updatePressState(true, null),
      onTapUp: (_) => updatePressState(false, null),
      onTapCancel: () => updatePressState(false, null),
      onTap: _activate,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      child: semanticContent,
    );
    trigger = Semantics(
      enabled: true,
      button: true,
      // Disclosure state: announce open/closed alongside the button role, so AT
      // reports isExpanded. Matches NakedMenu/NakedSelect/NakedAccordion.
      expanded: _menuController.isOpen,
      label: widget.semanticLabel,
      onTap: _activate,
      child: trigger,
    );
    trigger = MouseRegion(
      onEnter: (_) => updateHoverState(true, null),
      onExit: (_) => updateHoverState(false, null),
      cursor: SystemMouseCursors.click,
      child: trigger,
    );

    return Shortcuts(
      shortcuts: NakedIntentActions.button.shortcuts,
      child: Actions(
        actions: NakedIntentActions.button.actions(
          onPressed: _handleKeyboardActivation,
        ),
        child: trigger,
      ),
    );
  }

  Widget _buildTrigger(FocusNode returnNode, FocusNode? childFocusNode) {
    final excludeChildTraversal =
        widget.child is Focus && !identical(returnNode, childFocusNode);

    if (widget.openOnTap) {
      if (identical(returnNode, childFocusNode)) {
        return _buildChildOwnedTrigger(childFocusNode!);
      }

      // Wrap NakedButton (rather than extend it with an `expanded` param) so the
      // disclosure state merges onto the button's node. Mirrors NakedMenu.
      return Semantics(
        expanded: _menuController.isOpen,
        child: NakedButton(
          onPressed: _toggle,
          focusNode: returnNode,
          semanticLabel: widget.semanticLabel,
          child: excludeChildTraversal
              ? ExcludeFocusTraversal(child: widget.child!)
              : widget.child,
          builder: (context, buttonState, child) {
            return NakedStateScopeBuilder(
              value: NakedPopoverState(
                states: buttonState.states,
                isOpen: _menuController.isOpen,
              ),
              child: child,
              builder: widget.builder,
            );
          },
        ),
      );
    }

    final child = NakedStateScopeBuilder(
      value: NakedPopoverState(
        states: const <WidgetState>{},
        isOpen: _menuController.isOpen,
      ),
      child: widget.child,
      builder: widget.builder,
    );

    if (identical(returnNode, childFocusNode)) return child;

    return Focus(
      focusNode: returnNode,
      child: excludeChildTraversal
          ? ExcludeFocusTraversal(child: child)
          : child,
    );
  }

  @override
  void didUpdateWidget(covariant NakedPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateObservedChildFocusNode();
  }

  @override
  void dispose() {
    _keyboardPressTimer?.cancel();
    _keyboardPressTimer = null;
    _observedChildFocusNode?.removeListener(_handleChildFocusChange);
    _observedChildFocusNode = null;
    _internalTriggerNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final childFocusNode = _extractChildFocusNode();
    final returnNode =
        widget.triggerFocusNode ?? childFocusNode ?? _internalTriggerNode;

    final result = AnchoredOverlayShell(
      controller: _menuController,
      triggerFocusNode: returnNode,
      positioningAnchorKey: widget.anchorKey,
      consumeOutsideTaps: widget.consumeOutsideTaps,
      onOpen: _handleOpen,
      onClose: _handleClose,
      onOpenRequested: widget.onOpenRequested ?? (_, show) => show(),
      onCloseRequested: widget.onCloseRequested ?? (hide) => hide(),
      useRootOverlay: widget.useRootOverlay,
      closeOnClickOutside: true,
      positioning: widget.positioning,
      overlayBuilder: (context, info) {
        return widget.popoverBuilder(context, info);
      },
      child: _buildTrigger(returnNode, childFocusNode),
    );

    return widget.excludeSemantics ? ExcludeSemantics(child: result) : result;
  }
}
