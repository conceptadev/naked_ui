import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';

import 'base/overlay_base.dart';
import 'naked_button.dart';
import 'utilities/anchored_overlay_shell.dart';
import 'utilities/intents.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/positioning.dart';
import 'utilities/state.dart';

/// Immutable view passed to [NakedSelect.builder].
class NakedSelectState<T> extends NakedState {
  /// Whether the overlay is currently open.
  final bool isOpen;

  /// Currently selected value, if any.
  final T? value;

  /// Creates an immutable snapshot of select state.
  NakedSelectState({
    required super.states,
    required this.isOpen,
    required this.value,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedSelectState<T> &&
        statesEqual(other) &&
        other.isOpen == isOpen &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(statesHashCode, isOpen, value);

  /// Returns the nearest [NakedSelectState] of the requested type.
  static NakedSelectState<S> of<S>(BuildContext context) =>
      NakedState.of(context);

  /// Returns the nearest [NakedSelectState] if available.
  static NakedSelectState<S>? maybeOf<S>(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf<S>(BuildContext context) =>
      NakedState.controllerOf<NakedSelectState<S>>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf<S>(BuildContext context) =>
      NakedState.maybeControllerOf<NakedSelectState<S>>(context);

  /// Whether a selection exists.
  bool get hasValue => value != null;
}

/// Immutable view passed to [NakedSelectOption] builders.
class NakedSelectOptionState<T> extends NakedState {
  /// The option's value.
  final T value;

  /// Creates an immutable snapshot for the option associated with [value].
  NakedSelectOptionState({required super.states, required this.value});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedSelectOptionState<T> &&
        statesEqual(other) &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(statesHashCode, value);

  /// Returns the nearest [NakedSelectOptionState] of the requested type.
  static NakedSelectOptionState<S> of<S>(BuildContext context) =>
      NakedState.of(context);

  /// Returns the nearest [NakedSelectOptionState] if available.
  static NakedSelectOptionState<S>? maybeOf<S>(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf<S>(BuildContext context) =>
      NakedState.controllerOf<NakedSelectOptionState<S>>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf<S>(BuildContext context) =>
      NakedState.maybeControllerOf<NakedSelectOptionState<S>>(context);
}

/// Internal scope provided by [NakedSelect] to its overlay subtree.
class _NakedSelectScope<T> extends OverlayScope<T> {
  const _NakedSelectScope({
    super.key,
    required super.child,
    required this.close,
    required this.closeOnSelect,
    required this.enabled,
    this.onChanged,
    this.value,
  });

  /// Returns the [_NakedSelectScope] that most tightly encloses the given [context].
  ///
  /// If no [NakedSelect] ancestor is found, this method throws a [FlutterError].
  static _NakedSelectScope<T> of<T>(BuildContext context) {
    return OverlayScope.of(
      context,
      scopeConsumer: NakedSelectOption,
      scopeOwner: NakedSelect,
    );
  }

  final VoidCallback close;
  final bool closeOnSelect;
  final bool enabled;
  final ValueChanged<T?>? onChanged;

  final T? value;

  @override
  bool updateShouldNotify(covariant _NakedSelectScope<T> oldWidget) {
    return close != oldWidget.close ||
        closeOnSelect != oldWidget.closeOnSelect ||
        enabled != oldWidget.enabled ||
        onChanged != oldWidget.onChanged ||
        value != oldWidget.value;
  }
}

/// Widget-based select option that binds to the nearest [NakedSelect] scope.
///
/// This enables fully declarative composition inside [NakedSelect.overlayBuilder]
/// without relying on the data-driven approach.
class NakedSelectOption<T> extends OverlayItem<T, NakedSelectOptionState<T>> {
  /// Creates a selectable option associated with [value].
  const NakedSelectOption({
    super.key,
    required super.value,
    super.enabled = true,
    super.semanticLabel,
    super.child,
    super.builder,
  });

  /// Handles selection of this option.
  void _handleSelection(_NakedSelectScope<T> scope) {
    scope.onChanged?.call(value);
    if (scope.closeOnSelect) scope.close();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _NakedSelectScope.of<T>(context);

    final isSelected = scope.value == value;
    final effectiveEnabled = enabled && scope.enabled;
    final onPressed = effectiveEnabled ? () => _handleSelection(scope) : null;

    return buildButton(
      onPressed: onPressed,
      effectiveEnabled: effectiveEnabled,
      isSelected: isSelected,
      semanticsRole: SemanticsRole.menuItem,
      mapStates: (states) {
        return NakedSelectOptionState<T>(states: states, value: value);
      },
    );
  }
}

/// Headless select/dropdown that renders items in an overlay anchored to a trigger.
///
/// ## Keyboard Navigation
///
/// The select follows Flutter's standard keyboard navigation patterns:
///
/// ### Opening and Closing
/// - **Space/Enter on trigger**: Opens the overlay
/// - **Escape**: Closes the overlay and returns focus to trigger
/// - **Click outside**: Closes the overlay (if [closeOnClickOutside] is true)
///
/// ### Navigating Items
/// - **Arrow Up/Down**: Navigate between focusable items in the overlay
/// - **Enter/Space on item**: Selects the focused item
/// - **Tab**: Moves focus through items in traversal order
/// - **PageUp/PageDown**: Move focus by ~10 traversal steps (policy-driven)
///
/// ### Focus Management
/// When the overlay opens, focus transfers to the overlay container but does NOT
/// automatically focus the first item. Users must use arrow keys to navigate to
/// items before selecting them. This follows Flutter Material patterns where
/// explicit navigation is required.
///
/// The focus behavior ensures:
/// - Keyboard-only users can access all functionality
/// - Screen readers receive proper focus announcements
/// - Navigation is predictable and explicit
///
/// ### Example Usage
/// ```dart
/// NakedSelect<String>(
///   builder: (context, state) => Text('Select: ${state.value ?? 'None'}'),
///   overlayBuilder: (context, info) => Column(
///     children: [
///       NakedSelect.Option(value: 'apple', child: Text('Apple')),
///       NakedSelect.Option(value: 'banana', child: Text('Banana')),
///     ],
///   ),
///   onChanged: (value) => print('Selected: $value'),
/// )
/// ```
///
/// See also:
/// - [NakedSelectOption], for individual selectable items
/// - [NakedMenu], for action-based menus with similar keyboard behavior
class NakedSelect<T> extends StatefulWidget {
  /// Creates a headless select controlled by [value].
  const NakedSelect({
    super.key,
    this.child,
    this.builder,
    required this.overlayBuilder,
    this.value,
    this.onChanged,
    this.closeOnSelect = true,
    this.closeOnClickOutside = true,
    this.enabled = true,
    this.mouseCursor = SystemMouseCursors.click,
    this.triggerFocusNode,
    this.semanticLabel,
    this.positioning = const OverlayPositionConfig(
      alignment: OverlayAlignment.center,
    ),
    this.onOpen,
    this.onClose,
    this.open,
    this.onOpenChanged,
    this.onCanceled,
    this.onOpenRequested,
    this.onCloseRequested,
    this.consumeOutsideTaps = true,
    this.useRootOverlay = false,
    this.excludeSemantics = false,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       );

  /// Type alias for [NakedSelectOption] for cleaner API access.
  static final Option = NakedSelectOption.new;

  /// The static trigger widget.
  final Widget? child;

  /// Builds the trigger surface.
  final ValueWidgetBuilder<NakedSelectState<T>>? builder;

  /// Builds the overlay panel.
  final RawMenuAnchorOverlayBuilder overlayBuilder;

  /// Single selection value.
  final T? value;

  /// Callback for single selection changes.
  ///
  /// When null, the select is non-interactive because [value] is controlled by
  /// the caller and cannot be updated.
  final ValueChanged<T?>? onChanged;

  /// Whether selecting an item closes the menu.
  final bool closeOnSelect;

  /// Whether tapping outside closes the menu.
  final bool closeOnClickOutside;

  /// Whether the select is interactive.
  final bool enabled;

  /// The mouse cursor for the trigger when the select is interactive.
  ///
  /// Defaults to [SystemMouseCursors.click]. When the select is disabled, the
  /// trigger falls back to [SystemMouseCursors.basic].
  final MouseCursor mouseCursor;

  /// Focus node for the trigger.
  final FocusNode? triggerFocusNode;

  /// Optional semantics label for the trigger.
  final String? semanticLabel;

  /// Overlay positioning configuration.
  final OverlayPositionConfig positioning;

  /// Called when the select overlay opens.
  final VoidCallback? onOpen;

  /// Called when the select overlay closes.
  final VoidCallback? onClose;

  /// Controls whether the overlay is open.
  ///
  /// When null, [NakedSelect] manages its own open state. When non-null, user
  /// interactions request changes through [onOpenChanged] and the visible
  /// overlay follows this value.
  final bool? open;

  /// Called when a controlled or observed open-state change is requested.
  final ValueChanged<bool>? onOpenChanged;

  /// Called when the select closes without a selection.
  final VoidCallback? onCanceled;

  /// Open/close interceptors.
  final RawMenuAnchorOpenRequestedCallback? onOpenRequested;

  /// Intercepts close requests so callers can coordinate custom transitions.
  final RawMenuAnchorCloseRequestedCallback? onCloseRequested;

  /// Whether outside taps on the trigger are consumed.
  final bool consumeOutsideTaps;

  /// Whether to target the root overlay instead of the nearest ancestor.
  final bool useRootOverlay;

  /// Whether to exclude this widget from the semantic tree.
  ///
  /// When true, the widget and its children are hidden from accessibility services.
  final bool excludeSemantics;

  @override
  State<NakedSelect<T>> createState() => _NakedSelectState<T>();
}

class _NakedSelectState<T> extends State<NakedSelect<T>>
    with OverlayStateMixin<NakedSelect<T>> {
  // ignore: dispose-fields
  late final MenuController _menuController;

  /// Number of items to jump when pressing PageUp/PageDown.
  static const int _pageJumpSize = 10;

  @override
  void initState() {
    super.initState();
    _menuController = MenuController();
  }

  T? get _effectiveValue => widget.value;
  bool get _isEnabled => widget.enabled && widget.onChanged != null;

  bool get _isControlled => widget.open != null;

  void _requestOpen(bool open) {
    if (!_isEnabled && open) return;
    if (_isControlled) {
      if (widget.open != open) widget.onOpenChanged?.call(open);
      return;
    }
    if (open == _menuController.isOpen) return;
    open ? _menuController.open() : _menuController.close();
  }

  void _toggle() => _requestOpen(!_menuController.isOpen);

  void _scheduleControlledSync() {
    if (!_isControlled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isControlled) return;
      final shouldOpen = _isEnabled && widget.open!;
      if (shouldOpen == _menuController.isOpen) return;
      shouldOpen ? _menuController.open() : _menuController.close();
    });
  }

  void _handleOpen() {
    handleOpen(widget.onOpen);
    if (!_isControlled) widget.onOpenChanged?.call(true);
    if (mounted) setState(() {});
  }

  void _handleClose() {
    handleClose(
      onClose: widget.onClose,
      onCanceled: widget.onCanceled,
      triggerFocusNode: widget.triggerFocusNode,
    );
    if (!_isControlled) widget.onOpenChanged?.call(false);
    if (mounted) setState(() {});
  }

  void _handleSelection(T? value) {
    markSelectionMade();
    widget.onChanged?.call(value);
  }

  void _handlePageUp() {
    if (!_menuController.isOpen) return;
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus?.context == null) return;
    final focusScope = FocusScope.of(primaryFocus!.context!);
    for (var i = 0; i < _pageJumpSize; i++) {
      focusScope.previousFocus();
    }
  }

  void _handlePageDown() {
    if (!_menuController.isOpen) return;
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus?.context == null) return;
    final focusScope = FocusScope.of(primaryFocus!.context!);
    for (var i = 0; i < _pageJumpSize; i++) {
      focusScope.nextFocus();
    }
  }

  @override
  void didUpdateWidget(covariant NakedSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEnabled && _menuController.isOpen) {
      _requestOpen(false);
    }
    if (widget.open != oldWidget.open ||
        widget.enabled != oldWidget.enabled ||
        widget.onChanged != oldWidget.onChanged) {
      _scheduleControlledSync();
    }
  }

  bool get _isOpen => _menuController.isOpen;

  @override
  Widget build(BuildContext context) {
    _scheduleControlledSync();
    final semanticsValue = _effectiveValue?.toString();

    Widget selectWidget = AnchoredOverlayShell(
      controller: _menuController,
      overlayBuilder: (context, info) {
        return Semantics(
          role: SemanticsRole.menu,
          container: true,
          explicitChildNodes: true,
          // Preserve a child boundary while transitions hide option semantics.
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: _NakedSelectScope<T>(
              close: () => _requestOpen(false),
              closeOnSelect: widget.closeOnSelect,
              enabled: _isEnabled,
              onChanged: _handleSelection,
              value: _effectiveValue,
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
      onDismissRequested: () => _requestOpen(false),
      consumeOutsideTaps: widget.consumeOutsideTaps,
      useRootOverlay: widget.useRootOverlay,
      closeOnClickOutside: widget.closeOnClickOutside,
      triggerFocusNode: widget.triggerFocusNode,
      positioning: widget.positioning,
      child: NakedButton(
        onPressed: _isEnabled ? _toggle : null,
        enabled: _isEnabled,
        mouseCursor: widget.mouseCursor,
        focusNode: widget.triggerFocusNode,
        semanticLabel: widget.semanticLabel,
        child: widget.child,
        builder: (context, buttonState, child) {
          final selectState = NakedSelectState(
            states: buttonState.states,
            isOpen: _isOpen,
            value: _effectiveValue,
          );

          final trigger = NakedStateScopeBuilder(
            value: selectState,
            child: child,
            builder: widget.builder,
          );

          return widget.semanticLabel == null
              ? trigger
              : ExcludeSemantics(child: trigger);
        },
      ),
    );

    Widget result = widget.excludeSemantics
        ? ExcludeSemantics(child: selectWidget)
        : MergeSemantics(
            child: Semantics(
              container: true,
              expanded: _isOpen,
              value: semanticsValue,
              child: selectWidget,
            ),
          );

    return Shortcuts(
      shortcuts: NakedIntentActions.select.shortcuts,
      child: Actions(
        actions: NakedIntentActions.select.actions(
          onDismiss: () => _requestOpen(false),
          onOpenOverlay: _isEnabled ? () => _requestOpen(true) : null,
          onPageUp: _handlePageUp,
          onPageDown: _handlePageDown,
        ),
        child: result,
      ),
    );
  }
}
