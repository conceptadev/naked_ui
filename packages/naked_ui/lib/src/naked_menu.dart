import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'base/overlay_base.dart';
import 'naked_button.dart';
import 'utilities/anchored_overlay_shell.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/positioning.dart';
import 'utilities/state.dart';

/// Immutable view passed to [NakedMenu.builder].
class NakedMenuState extends NakedState {
  /// Whether the overlay is currently open.
  final bool isOpen;

  /// Creates an immutable snapshot of menu interaction state.
  NakedMenuState({required super.states, required this.isOpen});

  /// Returns the nearest [NakedMenuState] provided by [NakedStateScope].
  static NakedMenuState of(BuildContext context) => NakedState.of(context);

  /// Returns the nearest [NakedMenuState] if available.
  static NakedMenuState? maybeOf(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf(BuildContext context) =>
      NakedState.controllerOf<NakedMenuState>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf(BuildContext context) =>
      NakedState.maybeControllerOf<NakedMenuState>(context);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedMenuState &&
        statesEqual(other) &&
        other.isOpen == isOpen;
  }

  @override
  int get hashCode => Object.hash(statesHashCode, isOpen);
}

/// Immutable view passed to [NakedMenuItem] builders.
class NakedMenuItemState<T> extends NakedState {
  /// The menu item's value.
  final T value;

  /// Creates an immutable snapshot for the menu item associated with [value].
  NakedMenuItemState({required super.states, required this.value});

  /// Returns the nearest [NakedMenuItemState] of the requested type.
  static NakedMenuItemState<S> of<S>(BuildContext context) =>
      NakedState.of(context);

  /// Returns the nearest [NakedMenuItemState] if available.
  static NakedMenuItemState<S>? maybeOf<S>(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf<S>(BuildContext context) =>
      NakedState.controllerOf<NakedMenuItemState<S>>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf<S>(BuildContext context) =>
      NakedState.maybeControllerOf<NakedMenuItemState<S>>(context);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedMenuItemState<T> &&
        statesEqual(other) &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(statesHashCode, value);
}

/// Internal scope provided by [NakedMenu] to its overlay subtree.
class _NakedMenuScope<T> extends OverlayScope<T> {
  const _NakedMenuScope({
    required this.onSelected,
    required this.controller,
    required this.rootController,
    required super.child,
    super.key,
  });

  /// Returns the [_NakedMenuScope] that most tightly encloses the given [context].
  ///
  /// If no [NakedMenu] ancestor is found, throws a descriptive [FlutterError].
  static _NakedMenuScope<T> of<T>(BuildContext context) {
    return OverlayScope.of(
      context,
      scopeConsumer: NakedMenuItem,
      scopeOwner: NakedMenu,
    );
  }

  static _NakedMenuScope<T>? maybeOf<T>(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NakedMenuScope<T>>();

  final ValueChanged<T>? onSelected;
  final MenuController controller;
  final MenuController rootController;

  void closeAll() => rootController.close();

  @override
  bool updateShouldNotify(covariant _NakedMenuScope<T> oldWidget) {
    return onSelected != oldWidget.onSelected ||
        controller != oldWidget.controller ||
        rootController != oldWidget.rootController;
  }
}

/// Widget-based menu action that binds to the nearest [NakedMenu] scope.
///
/// This enables fully declarative composition inside [NakedMenu.overlayBuilder]
/// without relying on the data-driven [NakedMenuItem] list.
class NakedMenuItem<T> extends OverlayItem<T, NakedMenuItemState<T>> {
  /// Creates a menu item associated with [value].
  const NakedMenuItem({
    super.key,
    required super.value,
    super.enabled = true,
    super.semanticLabel,
    super.child,
    super.builder,
    this.closeOnActivate = true,
  });

  /// Whether the menu closes when this item is activated.
  ///
  /// Defaults to true. Set to false to keep the menu open after this
  /// item is selected, which is useful for toggle actions or when
  /// the menu contains interactive content.
  final bool closeOnActivate;

  void _handleActivation(_NakedMenuScope<T> menu) {
    menu.onSelected?.call(value);
    if (closeOnActivate) menu.closeAll();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _NakedMenuScope.of<T>(context);

    final VoidCallback? onPressed = enabled
        ? () => _handleActivation(scope)
        : null;

    return buildButton(
      onPressed: onPressed,
      effectiveEnabled: enabled,
      semanticsRole: SemanticsRole.menuItem,
      mapStates: (states) =>
          NakedMenuItemState<T>(states: states, value: value),
    );
  }
}

/// A checkable item in a [NakedMenu].
class NakedMenuCheckboxItem<T> extends OverlayItem<T, NakedMenuItemState<T>> {
  /// Creates a controlled menu checkbox item.
  const NakedMenuCheckboxItem({
    super.key,
    required super.value,
    required this.checked,
    this.onChanged,
    this.closeOnActivate = true,
    super.enabled = true,
    super.semanticLabel,
    super.child,
    super.builder,
  });

  /// Whether the item is checked.
  final bool checked;

  /// Called with the toggled checked value.
  final ValueChanged<bool>? onChanged;

  /// Whether activation closes the complete menu hierarchy.
  final bool closeOnActivate;

  @override
  Widget build(BuildContext context) {
    final menu = _NakedMenuScope.of<T>(context);
    final effectiveEnabled =
        enabled && (onChanged != null || menu.onSelected != null);

    void activate() {
      menu.onSelected?.call(value);
      onChanged?.call(!checked);
      if (closeOnActivate) menu.closeAll();
    }

    return buildButton(
      onPressed: effectiveEnabled ? activate : null,
      effectiveEnabled: effectiveEnabled,
      isChecked: checked,
      semanticsRole: SemanticsRole.menuItemCheckbox,
      mapStates: (states) =>
          NakedMenuItemState<T>(states: states, value: value),
    );
  }
}

/// Provides controlled selection state to [NakedMenuRadioItem] descendants.
class NakedMenuRadioGroup<T> extends InheritedWidget {
  /// Creates a typed menu radio group.
  const NakedMenuRadioGroup({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    required super.child,
  });

  /// The selected item value.
  final T value;

  /// Called when an item requests selection.
  final ValueChanged<T>? onChanged;

  /// Whether items in the group can be activated.
  final bool enabled;

  /// Returns the nearest radio group of type [S].
  static NakedMenuRadioGroup<S> of<S>(BuildContext context) {
    final group = context
        .dependOnInheritedWidgetOfExactType<NakedMenuRadioGroup<S>>();
    assert(
      group != null,
      'NakedMenuRadioItem<$S> requires a NakedMenuRadioGroup<$S>.',
    );

    return group!;
  }

  @override
  bool updateShouldNotify(NakedMenuRadioGroup<T> oldWidget) =>
      value != oldWidget.value ||
      onChanged != oldWidget.onChanged ||
      enabled != oldWidget.enabled;
}

/// A mutually exclusive item in a [NakedMenuRadioGroup].
class NakedMenuRadioItem<T> extends OverlayItem<T, NakedMenuItemState<T>> {
  /// Creates a typed menu radio item.
  const NakedMenuRadioItem({
    super.key,
    required super.value,
    this.closeOnActivate = true,
    super.enabled = true,
    super.semanticLabel,
    super.child,
    super.builder,
  });

  /// Whether activation closes the complete menu hierarchy.
  final bool closeOnActivate;

  @override
  Widget build(BuildContext context) {
    final menu = _NakedMenuScope.of<T>(context);
    final group = NakedMenuRadioGroup.of<T>(context);
    final checked = group.value == value;
    final effectiveEnabled =
        enabled &&
        group.enabled &&
        (group.onChanged != null || menu.onSelected != null);

    void activate() {
      menu.onSelected?.call(value);
      group.onChanged?.call(value);
      if (closeOnActivate) menu.closeAll();
    }

    return buildButton(
      onPressed: effectiveEnabled ? activate : null,
      effectiveEnabled: effectiveEnabled,
      isChecked: checked,
      inMutuallyExclusiveGroup: true,
      semanticsRole: SemanticsRole.menuItemRadio,
      mapStates: (states) =>
          NakedMenuItemState<T>(states: states, value: value),
    );
  }
}

class _OpenSubmenuIntent extends Intent {
  const _OpenSubmenuIntent();
}

class _CloseSubmenuIntent extends Intent {
  const _CloseSubmenuIntent();
}

/// A recursively nestable submenu inside a [NakedMenu].
class NakedMenuSubmenu<T> extends StatefulWidget {
  /// Creates a submenu with a menu-item trigger.
  const NakedMenuSubmenu({
    super.key,
    this.child,
    this.builder,
    required this.overlayBuilder,
    this.controller,
    this.enabled = true,
    this.hoverDelay = const Duration(milliseconds: 100),
    this.positioning = const OverlayPositionConfig(
      side: OverlaySide.right,
      alignment: OverlayAlignment.start,
      sideOffset: 4,
    ),
    this.focusNode,
    this.semanticLabel,
    this.onOpen,
    this.onClose,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       );

  /// Static trigger content.
  final Widget? child;

  /// Builds the trigger with its current interaction and open state.
  final ValueWidgetBuilder<NakedMenuState>? builder;

  /// Builds the child menu panel.
  final RawMenuAnchorOverlayBuilder overlayBuilder;

  /// Optional controller for programmatic submenu control.
  final MenuController? controller;

  /// Whether the submenu can be opened.
  final bool enabled;

  /// Delay before pointer hover opens or closes the submenu.
  final Duration hoverDelay;

  /// Placement of the child panel relative to the submenu trigger.
  final OverlayPositionConfig positioning;

  /// Optional focus node for the submenu trigger.
  final FocusNode? focusNode;

  /// Accessible name for the submenu trigger.
  final String? semanticLabel;

  /// Called after the submenu opens.
  final VoidCallback? onOpen;

  /// Called after the submenu closes.
  final VoidCallback? onClose;

  @override
  State<NakedMenuSubmenu<T>> createState() => _NakedMenuSubmenuState<T>();
}

class _NakedMenuSubmenuState<T> extends State<NakedMenuSubmenu<T>> {
  final MenuController _internalController = MenuController();
  final FocusNode _internalFocusNode = FocusNode(
    debugLabel: 'NakedMenuSubmenu trigger',
  );
  final GlobalKey _overlayKey = GlobalKey();
  Timer? _hoverTimer;
  bool _focusFirstOnOpen = false;
  bool _restoreFocusOnClose = false;
  late _NakedMenuScope<T> _parentMenu;

  MenuController get _controller => widget.controller ?? _internalController;
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parentMenu = _NakedMenuScope.of<T>(context);
  }

  void _cancelHoverTimer() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
  }

  void _open({required bool focusFirst}) {
    if (!widget.enabled) return;
    _cancelHoverTimer();
    _focusFirstOnOpen = _focusFirstOnOpen || focusFirst;
    if (_controller.isOpen) {
      if (_focusFirstOnOpen) _scheduleFirstItemFocus();
      return;
    }
    _parentMenu.controller.closeChildren();
    _controller.open();
  }

  void _close({required bool restoreFocus}) {
    _cancelHoverTimer();
    _restoreFocusOnClose = restoreFocus;
    _controller.close();
  }

  void _toggle() =>
      _controller.isOpen ? _close(restoreFocus: true) : _open(focusFirst: true);

  void _scheduleHoverOpen() {
    _cancelHoverTimer();
    _hoverTimer = Timer(widget.hoverDelay, () {
      if (mounted) _open(focusFirst: false);
    });
  }

  void _scheduleHoverClose() {
    _cancelHoverTimer();
    _hoverTimer = Timer(widget.hoverDelay, () {
      if (mounted) _close(restoreFocus: false);
    });
  }

  void _scheduleFirstItemFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.isOpen) return;
      final overlayContext = _overlayKey.currentContext;
      if (overlayContext == null) return;
      FocusScope.of(overlayContext).nextFocus();
      _focusFirstOnOpen = false;
    });
  }

  void _handleOpen() {
    if (mounted) setState(() {});
    widget.onOpen?.call();
    if (_focusFirstOnOpen) _scheduleFirstItemFocus();
  }

  void _handleClose() {
    if (mounted) setState(() {});
    widget.onClose?.call();
    if (_restoreFocusOnClose) _focusNode.requestFocus();
    _restoreFocusOnClose = false;
    _focusFirstOnOpen = false;
  }

  Map<ShortcutActivator, Intent> _shortcuts(TextDirection direction) => {
    SingleActivator(
      direction == TextDirection.ltr
          ? LogicalKeyboardKey.arrowRight
          : LogicalKeyboardKey.arrowLeft,
    ): const _OpenSubmenuIntent(),
    SingleActivator(
      direction == TextDirection.ltr
          ? LogicalKeyboardKey.arrowLeft
          : LogicalKeyboardKey.arrowRight,
    ): const _CloseSubmenuIntent(),
  };

  Map<Type, Action<Intent>> get _actions => {
    _OpenSubmenuIntent: CallbackAction<_OpenSubmenuIntent>(
      onInvoke: (_) {
        _open(focusFirst: true);
        return null;
      },
    ),
    _CloseSubmenuIntent: CallbackAction<_CloseSubmenuIntent>(
      onInvoke: (_) {
        _close(restoreFocus: true);
        return null;
      },
    ),
  };

  @override
  void didUpdateWidget(covariant NakedMenuSubmenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _controller.isOpen) {
      _close(restoreFocus: false);
    }
  }

  @override
  void dispose() {
    _cancelHoverTimer();
    _internalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final button = NakedButton(
      onPressed: widget.enabled ? _toggle : null,
      enabled: widget.enabled,
      focusNode: _focusNode,
      semanticLabel: widget.semanticLabel,
      child: widget.child,
      builder: (context, state, child) {
        final trigger = NakedStateScopeBuilder(
          value: NakedMenuState(
            states: state.states,
            isOpen: _controller.isOpen,
          ),
          child: child,
          builder: widget.builder,
        );

        return widget.semanticLabel == null
            ? trigger
            : ExcludeSemantics(child: trigger);
      },
    );
    final trigger = MouseRegion(
      onEnter: (_) => _scheduleHoverOpen(),
      onExit: (_) => _scheduleHoverClose(),
      child: MergeSemantics(
        child: Semantics(
          role: SemanticsRole.menuItem,
          expanded: _controller.isOpen,
          child: button,
        ),
      ),
    );

    return AnchoredOverlayShell(
      controller: _controller,
      triggerFocusNode: _focusNode,
      consumeOutsideTaps: false,
      closeOnClickOutside: true,
      positioning: widget.positioning,
      onOpen: _handleOpen,
      onClose: _handleClose,
      onDismissRequested: () => _close(restoreFocus: true),
      overlayBuilder: (context, info) {
        return Shortcuts(
          shortcuts: _shortcuts(direction),
          child: Actions(
            actions: _actions,
            child: MouseRegion(
              key: _overlayKey,
              onEnter: (_) => _cancelHoverTimer(),
              child: Semantics(
                role: SemanticsRole.menu,
                container: true,
                explicitChildNodes: true,
                child: _NakedMenuScope<T>(
                  onSelected: _parentMenu.onSelected,
                  controller: _controller,
                  rootController: _parentMenu.rootController,
                  child: Builder(
                    builder: (context) => widget.overlayBuilder(context, info),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Shortcuts(
        shortcuts: _shortcuts(direction),
        child: Actions(actions: _actions, child: trigger),
      ),
    );
  }
}

/// A headless menu that renders items in an overlay anchored to its trigger.
///
/// ## Keyboard Navigation
///
/// The menu follows Flutter's standard keyboard navigation patterns:
///
/// ### Opening and Closing
/// - **Space/Enter on trigger**: Opens the overlay
/// - **Escape**: Closes the overlay and returns focus to trigger
/// - **Click outside**: Closes the overlay (if [closeOnClickOutside] is true)
///
/// ### Navigating Items
/// - **Arrow Up/Down**: Navigate between focusable items in the overlay
/// - **Enter/Space on item**: Activates the focused item
/// - **Tab**: Moves focus through items in traversal order
///
/// ### Focus Management
/// When the overlay opens, focus transfers to the overlay container but does NOT
/// automatically focus the first item. Users must use arrow keys to navigate to
/// items before activating them. This follows Flutter Material patterns where
/// explicit navigation is required.
///
/// The focus behavior ensures:
/// - Keyboard-only users can access all functionality
/// - Screen readers receive proper focus announcements
/// - Navigation is predictable and explicit
///
/// ### Example Usage
/// ```dart
/// final menuController = MenuController();
/// NakedMenu<String>(
///   controller: menuController,
///   builder: (context, state) => Text('Menu'),
///   overlayBuilder: (context, info) => Column(
///     children: [
///       NakedMenu.Item(value: 'copy', child: Text('Copy')),
///       NakedMenu.Item(value: 'paste', child: Text('Paste')),
///     ],
///   ),
///   onSelected: (value) => print('Activated: $value'),
/// )
/// ```
///
/// See also:
/// - [NakedMenuItem], for individual actionable items
/// - [NakedSelect], for selection-based menus with similar keyboard behavior
class NakedMenu<T> extends StatefulWidget {
  /// Creates a headless menu managed by [controller].
  const NakedMenu({
    super.key,
    this.child,
    this.builder,
    required this.overlayBuilder,
    required this.controller,
    this.onSelected,
    this.onOpen,
    this.onClose,
    this.onCanceled,
    this.onOpenRequested,
    this.onCloseRequested,
    this.consumeOutsideTaps = true,
    this.useRootOverlay = false,
    this.closeOnClickOutside = true,
    this.triggerFocusNode,
    this.positioning = const OverlayPositionConfig(),
    this.semanticLabel,
    this.excludeSemantics = false,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       );

  /// Type alias for [NakedMenuItem] for cleaner API access.
  static final Item = NakedMenuItem.new;

  /// Type alias for [NakedMenuCheckboxItem].
  static final CheckboxItem = NakedMenuCheckboxItem.new;

  /// Type alias for [NakedMenuRadioGroup].
  static final RadioGroup = NakedMenuRadioGroup.new;

  /// Type alias for [NakedMenuRadioItem].
  static final RadioItem = NakedMenuRadioItem.new;

  /// Type alias for [NakedMenuSubmenu].
  static final Submenu = NakedMenuSubmenu.new;

  /// The static trigger widget.
  final Widget? child;

  /// Builds the trigger surface.
  final ValueWidgetBuilder<NakedMenuState>? builder;

  /// Builds the overlay panel.
  final RawMenuAnchorOverlayBuilder overlayBuilder;

  /// Controls show/hide of the underlying [RawMenuAnchor] and manages selection state.
  final MenuController controller;

  /// Called when an item is selected.
  final ValueChanged<T>? onSelected;

  /// Called when the menu opens.
  final VoidCallback? onOpen;

  /// Called when the menu closes.
  final VoidCallback? onClose;

  /// Called when the menu closes without a selection.
  final VoidCallback? onCanceled;

  /// Open/close interceptors (for example, to drive animations).
  final RawMenuAnchorOpenRequestedCallback? onOpenRequested;

  /// Intercepts close requests so callers can coordinate custom transitions.
  final RawMenuAnchorCloseRequestedCallback? onCloseRequested;

  /// Whether taps outside the overlay close the menu.
  final bool closeOnClickOutside;

  /// Whether outside taps on the trigger are consumed.
  final bool consumeOutsideTaps;

  /// Whether to target the root overlay instead of the nearest ancestor.
  final bool useRootOverlay;

  /// Optional focus node for the trigger.
  final FocusNode? triggerFocusNode;

  /// Overlay positioning configuration.
  final OverlayPositionConfig positioning;

  /// Semantic label for the menu trigger.
  final String? semanticLabel;

  /// Whether to exclude this widget from the semantic tree.
  ///
  /// When true, the widget and its children are hidden from accessibility services.
  final bool excludeSemantics;

  @override
  State<NakedMenu<T>> createState() => _NakedMenuState<T>();
}

class _NakedMenuState<T> extends State<NakedMenu<T>>
    with OverlayStateMixin<NakedMenu<T>> {
  bool get _isOpen => widget.controller.isOpen;

  void _toggle() => widget.controller.isOpen
      ? widget.controller.close()
      : widget.controller.open();

  void _handleOpen() {
    handleOpen(widget.onOpen);
    if (mounted) setState(() {});
  }

  void _handleClose() {
    handleClose(
      onClose: widget.onClose,
      onCanceled: widget.onCanceled,
      triggerFocusNode: widget.triggerFocusNode,
    );
    if (mounted) setState(() {});
  }

  void _handleSelection(T value) {
    markSelectionMade();
    widget.onSelected?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final parentMenu = _NakedMenuScope.maybeOf<T>(context);
    Widget button = NakedButton(
      onPressed: _toggle,
      focusNode: widget.triggerFocusNode,
      semanticLabel: widget.semanticLabel,
      child: widget.child,
      builder: (context, buttonState, child) {
        final menuState = NakedMenuState(
          states: buttonState.states,
          isOpen: _isOpen,
        );

        final trigger = NakedStateScopeBuilder(
          value: menuState,
          child: widget.child,
          builder: widget.builder,
        );

        return widget.semanticLabel == null
            ? trigger
            : ExcludeSemantics(child: trigger);
      },
    );

    Widget menuChild = widget.excludeSemantics
        ? ExcludeSemantics(child: button)
        : Semantics(expanded: _isOpen, child: button);

    return AnchoredOverlayShell(
      controller: widget.controller,
      overlayBuilder: (context, info) {
        return Semantics(
          role: SemanticsRole.menu,
          container: true,
          explicitChildNodes: true,
          // Preserve a child boundary while transitions hide item semantics.
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: _NakedMenuScope<T>(
              onSelected: widget.onSelected == null && parentMenu != null
                  ? parentMenu.onSelected
                  : _handleSelection,
              controller: widget.controller,
              rootController: parentMenu?.rootController ?? widget.controller,
              child: Builder(
                builder: (context) => widget.overlayBuilder(context, info),
              ),
            ),
          ),
        );
      },
      onOpen: _handleOpen,
      onClose: _handleClose,
      onOpenRequested: widget.onOpenRequested,
      onCloseRequested: widget.onCloseRequested,
      consumeOutsideTaps: widget.consumeOutsideTaps,
      useRootOverlay: widget.useRootOverlay,
      closeOnClickOutside: widget.closeOnClickOutside,
      triggerFocusNode: widget.triggerFocusNode,
      positioning: widget.positioning,
      child: menuChild,
    );
  }
}
