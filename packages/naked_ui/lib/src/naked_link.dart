import 'package:flutter/widgets.dart';

import 'mixins/naked_mixins.dart';
import 'utilities/intents.dart';
import 'utilities/naked_focusable_detector.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/state.dart';

/// An immutable snapshot of a [NakedLink]'s interaction state.
class NakedLinkState extends NakedState {
  /// Creates a snapshot with the current interaction [states] and [linkUrl].
  NakedLinkState({required super.states, required this.linkUrl});

  /// The optional destination supplied to the Link.
  final Uri? linkUrl;

  /// Returns the nearest [NakedLinkState] provided by [NakedStateScope].
  static NakedLinkState of(BuildContext context) => NakedState.of(context);

  /// Returns the nearest [NakedLinkState], if one is available.
  static NakedLinkState? maybeOf(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest state scope.
  static WidgetStatesController controllerOf(BuildContext context) =>
      NakedState.controllerOf<NakedLinkState>(context);

  /// Returns the nearest state scope's controller, if one is available.
  static WidgetStatesController? maybeControllerOf(BuildContext context) =>
      NakedState.maybeControllerOf<NakedLinkState>(context);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedLinkState &&
        statesEqual(other) &&
        other.linkUrl == linkUrl;
  }

  @override
  int get hashCode => Object.hash(statesHashCode, linkUrl);
}

/// A headless Link with caller-owned activation and no launcher dependency.
///
/// Primary tap, Enter, Numpad Enter, and semantic tap call [onPressed] while
/// the Link is enabled. Space remains unclaimed. The [builder] owns all visual
/// styling, and a supplied [focusNode] remains caller-owned.
///
/// [linkUrl] is optional semantics metadata. Flutter web maps a non-null value
/// to an anchor `href`, so omit it when [onPressed] performs navigation; a DOM
/// activation can otherwise call the callback and follow the anchor.
class NakedLink extends StatefulWidget {
  /// Creates a Link with either [child] or [builder] as its visual surface.
  const NakedLink({
    super.key,
    this.child,
    this.builder,
    this.onPressed,
    this.linkUrl,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.mouseCursor,
    this.enableFeedback = true,
    this.onFocusChange,
    this.onHoverChange,
    this.onPressChange,
    this.semanticLabel,
    this.semanticHint,
    this.excludeSemantics = false,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       );

  /// The visual Link content.
  final Widget? child;

  /// Builds the Link using the current immutable state.
  final ValueWidgetBuilder<NakedLinkState>? builder;

  /// Performs application-owned navigation when the Link activates.
  final VoidCallback? onPressed;

  /// An optional destination exposed through Flutter's Link semantics.
  ///
  /// On Flutter web, this becomes an anchor `href` while the Link is enabled.
  /// Omit it when [onPressed] performs navigation so a DOM activation does not
  /// have two navigation owners.
  final Uri? linkUrl;

  /// Whether the Link may activate when [onPressed] is also non-null.
  final bool enabled;

  /// The optional caller-owned focus node.
  final FocusNode? focusNode;

  /// Whether the Link should request focus when first built.
  final bool autofocus;

  /// The cursor used while effectively enabled.
  ///
  /// Defaults to [SystemMouseCursors.click]. Disabled Links always use
  /// [SystemMouseCursors.basic].
  final MouseCursor? mouseCursor;

  /// Whether accepted activations provide platform feedback.
  final bool enableFeedback;

  /// Called when keyboard focus changes.
  final ValueChanged<bool>? onFocusChange;

  /// Called when pointer hover changes.
  final ValueChanged<bool>? onHoverChange;

  /// Called when primary-pointer press state changes.
  final ValueChanged<bool>? onPressChange;

  /// The optional caller-localized accessible name.
  ///
  /// A non-empty value replaces descendant naming semantics. Null or
  /// whitespace-only values let visible child text supply the name.
  final String? semanticLabel;

  /// Optional caller-localized description of a non-obvious result.
  final String? semanticHint;

  /// Whether to hide the Link and its subtree from semantics.
  ///
  /// Callers remain responsible for an equivalent accessible navigation path.
  final bool excludeSemantics;

  bool get _effectiveEnabled => enabled && onPressed != null;

  @override
  State<NakedLink> createState() => _NakedLinkState();
}

class _NakedLinkState extends State<NakedLink>
    with WidgetStatesMixin<NakedLink> {
  void _handleActivation() {
    if (!widget._effectiveEnabled) return;

    if (widget.enableFeedback) {
      Feedback.forTap(context);
    }
    widget.onPressed!();
  }

  void _handlePressStart(TapDownDetails details) {
    updatePressState(true, widget.onPressChange);
  }

  void _handlePressEnd() {
    updatePressState(false, widget.onPressChange);
  }

  void _clearInteractionStates() {
    final endedPress = updateState(WidgetState.pressed, false);
    final endedHover = updateState(WidgetState.hovered, false);
    final endedFocus = updateState(WidgetState.focused, false);
    if (!endedPress && !endedHover && !endedFocus) return;

    final onPressChange = widget.onPressChange;
    final onHoverChange = widget.onHoverChange;
    final onFocusChange = widget.onFocusChange;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (endedPress) onPressChange?.call(false);
      if (endedHover) onHoverChange?.call(false);
      if (endedFocus) onFocusChange?.call(false);
    });
  }

  @override
  void initializeWidgetStates() {
    updateDisabledState(!widget._effectiveEnabled);
  }

  @override
  void didUpdateWidget(covariant NakedLink oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasEnabled = oldWidget.enabled && oldWidget.onPressed != null;
    if (wasEnabled == widget._effectiveEnabled) return;

    updateDisabledState(!widget._effectiveEnabled);
    if (!widget._effectiveEnabled) _clearInteractionStates();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget._effectiveEnabled;
    final semanticLabel = widget.semanticLabel;
    final hasSemanticLabel = semanticLabel?.trim().isNotEmpty ?? false;

    Widget result = GestureDetector(
      onTapDown: isEnabled ? _handlePressStart : null,
      onTapUp: isEnabled ? (_) => _handlePressEnd() : null,
      onTapCancel: isEnabled ? _handlePressEnd : null,
      onTap: isEnabled ? _handleActivation : null,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      child: NakedStateScopeBuilder(
        value: NakedLinkState(states: widgetStates, linkUrl: widget.linkUrl),
        child: widget.child,
        builder: widget.builder,
      ),
    );

    if (!widget.excludeSemantics) {
      result = Semantics(
        enabled: isEnabled,
        link: isEnabled,
        linkUrl: isEnabled ? widget.linkUrl : null,
        label: hasSemanticLabel ? semanticLabel : null,
        hint: widget.semanticHint,
        excludeSemantics: hasSemanticLabel,
        onTap: isEnabled ? _handleActivation : null,
        child: result,
      );
    }

    result = NakedFocusableDetector(
      enabled: isEnabled,
      autofocus: widget.autofocus,
      canRequestFocus: isEnabled,
      includeSemantics: !widget.excludeSemantics,
      onFocusChange: (focused) {
        updateFocusState(focused, widget.onFocusChange);
      },
      onHoverChange: (hovered) {
        updateHoverState(hovered, widget.onHoverChange);
      },
      focusNode: widget.focusNode,
      mouseCursor: isEnabled
          ? (widget.mouseCursor ?? SystemMouseCursors.click)
          : SystemMouseCursors.basic,
      shortcuts: NakedIntentActions.link.shortcuts,
      actions: NakedIntentActions.link.actions(onPressed: _handleActivation),
      debugLabel: 'NakedLink',
      child: result,
    );

    return widget.excludeSemantics ? ExcludeSemantics(child: result) : result;
  }
}
