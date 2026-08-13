import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/link.dart' as launcher;
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'mixins/naked_mixins.dart';
import 'utilities/intents.dart';
import 'utilities/naked_focusable_detector.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/state.dart';
import 'utilities/web_event_modifiers_stub.dart'
    if (dart.library.js_interop) 'utilities/web_event_modifiers_web.dart'
    as web_event_modifiers;

/// The result of resolving an ordinary [NakedLink] activation.
enum NakedLinkResolution {
  /// The resolver has requested navigation and platform navigation is skipped.
  handled,

  /// [NakedLink] continues with its platform-default navigation behavior.
  platformDefault,
}

/// Resolves an ordinary [NakedLink] activation for a subtree.
///
/// The callback receives the activating Link's [BuildContext] and its exact
/// destination URI. It is synchronous so a [NakedLink] can reliably prevent
/// duplicate platform navigation when it returns [NakedLinkResolution.handled].
typedef NakedLinkResolveCallback =
    NakedLinkResolution Function(BuildContext context, Uri linkUrl);

/// Supplies navigation policy to descendant [NakedLink] widgets.
///
/// The closest resolver wins. Resolvers observe only ordinary primary, Enter,
/// Numpad Enter, and semantic activation; browser-owned auxiliary actions such
/// as modified and middle clicks bypass this scope.
class NakedLinkResolver extends InheritedWidget {
  /// Creates a subtree navigation resolver.
  const NakedLinkResolver({
    required this.resolve,
    required super.child,
    super.key,
  });

  /// Resolves a descendant Link's ordinary activation.
  final NakedLinkResolveCallback resolve;

  /// Returns the closest [NakedLinkResolver], if one is in scope.
  static NakedLinkResolver? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NakedLinkResolver>();

  @override
  bool updateShouldNotify(NakedLinkResolver oldWidget) =>
      resolve != oldWidget.resolve;
}

/// An immutable snapshot of a [NakedLink]'s interaction state and destination.
class NakedLinkState extends NakedState {
  /// Creates a snapshot with the current interaction [states] and [linkUrl].
  NakedLinkState({required super.states, required this.linkUrl});

  /// The Link's destination, including while the Link is disabled.
  final Uri linkUrl;

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

/// A headless navigation Link with observable interaction state.
///
/// Primary pointer tap, Enter, Numpad Enter, and semantic tap use [linkUrl]
/// while [enabled]. [onActivated] observes each accepted ordinary activation,
/// then the nearest [NakedLinkResolver] decides whether to handle it or use
/// platform-default navigation. Space is not bound by this widget, so a
/// surrounding page retains its normal scrolling behavior. Secondary,
/// middle, and modified primary clicks remain browser-owned.
///
/// Naked UI delegates default navigation and the native web anchor to
/// `url_launcher`'s Link coordinator. The [builder] owns all visual styling. A
/// supplied [focusNode] remains caller-owned and is never disposed by Naked UI.
/// Callers own destination validation and must not pass untrusted URIs.
///
/// ```dart
/// NakedLink(
///   linkUrl: Uri.parse('https://example.com/docs'),
///   child: const Text('Documentation'),
///   builder: (context, state, child) => DecoratedBox(
///     decoration: BoxDecoration(
///       border: Border.all(
///         color: state.isFocused
///             ? const Color(0xFF2563EB)
///             : const Color(0x00000000),
///       ),
///     ),
///     child: child!,
///   ),
/// )
/// ```
class NakedLink extends StatefulWidget {
  /// Creates a Link with either [child] or [builder] as its visual surface.
  const NakedLink({
    super.key,
    this.child,
    this.builder,
    required this.linkUrl,
    this.onActivated,
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

  /// Observes an accepted ordinary activation before its navigation resolves.
  ///
  /// This callback cannot cancel navigation. Use [NakedLinkResolver] when a
  /// subtree needs to handle a destination itself.
  final ValueChanged<Uri>? onActivated;

  /// The destination exposed to assistive technologies and the web DOM.
  ///
  /// Naked UI accepts every URI unchanged. Callers are responsible for
  /// validating its destination and must not pass untrusted values.
  final Uri linkUrl;

  /// Whether the Link may activate.
  final bool enabled;

  /// The optional caller-owned focus node.
  ///
  /// Naked UI borrows this node and never disposes it.
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
  /// When non-empty, this replaces descendant naming semantics so the Link is
  /// announced once. Null or whitespace-only values let visible child text
  /// supply the name.
  final String? semanticLabel;

  /// Optional caller-localized accessible hint.
  final String? semanticHint;

  /// Whether to hide the Link and its subtree from semantics.
  ///
  /// This is an advanced escape hatch. Callers remain responsible for
  /// providing an equivalent accessible navigation path.
  final bool excludeSemantics;

  bool get _effectiveEnabled => enabled;

  @override
  State<NakedLink> createState() => _NakedLinkState();
}

class _NakedLinkState extends State<NakedLink>
    with WidgetStatesMixin<NakedLink> {
  // url_launcher's web delegate contributes Link semantics whenever it wraps
  // the Link. Keep that wrapper out of the disabled tree and use this key to
  // preserve the consumer subtree as it is added or removed.
  final _contentKey = GlobalKey(debugLabel: 'NakedLink content');
  var _modifiedPointerActivation = false;

  @override
  void initState() {
    super.initState();
    web_event_modifiers.ensureInitialized();
  }

  bool get _hasPointerModifier {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed;
  }

  bool get _isWebJavascriptLink =>
      kIsWeb && widget.linkUrl.scheme.toLowerCase() == 'javascript';

  bool get _isModifiedWebClick {
    return kIsWeb && web_event_modifiers.consumeModifiedClick();
  }

  void _handleModifiedActivation(launcher.FollowLink followLink) {
    _modifiedPointerActivation = false;
    if (_isWebJavascriptLink) {
      _followPlatformDefault(followLink);
    } else {
      unawaited(followLink());
    }
  }

  void _handleOrdinaryActivation(launcher.FollowLink followLink) {
    if (!widget._effectiveEnabled) return;

    if (widget.enableFeedback) {
      Feedback.forTap(context);
    }

    widget.onActivated?.call(widget.linkUrl);
    final resolution =
        NakedLinkResolver.maybeOf(context)?.resolve(context, widget.linkUrl) ??
        NakedLinkResolution.platformDefault;
    if (resolution == NakedLinkResolution.platformDefault) {
      _followPlatformDefault(followLink);
    }
  }

  void _followPlatformDefault(launcher.FollowLink followLink) {
    final scheme = widget.linkUrl.scheme.toLowerCase();
    final usesWebLauncher =
        _isWebJavascriptLink ||
        (kIsWeb && (scheme == 'http' || scheme == 'https'));
    if (usesWebLauncher) {
      // Keep javascript URIs on url_launcher_web's guarded path. Its Link
      // delegate otherwise exposes the URI directly through a DOM anchor.
      unawaited(_launchWebLink());
      return;
    }
    unawaited(followLink());
  }

  Future<void> _launchWebLink() async {
    try {
      final launched = await url_launcher.launchUrl(
        widget.linkUrl,
        webOnlyWindowName: '_self',
      );
      if (launched) return;

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('Could not launch Link ${widget.linkUrl}.'),
          stack: StackTrace.current,
          library: 'naked_ui',
          context: ErrorDescription('while following a NakedLink'),
        ),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'naked_ui',
          context: ErrorDescription('while following a NakedLink'),
        ),
      );
    }
  }

  void _handlePointerActivation(launcher.FollowLink followLink) {
    final modified = _modifiedPointerActivation || _hasPointerModifier;
    _modifiedPointerActivation = false;
    if (modified) {
      _handleModifiedActivation(followLink);
      return;
    }
    _handleOrdinaryActivation(followLink);
  }

  void _handlePressStart(TapDownDetails details) {
    _modifiedPointerActivation = _hasPointerModifier;
    if (_modifiedPointerActivation) return;
    updatePressState(true, widget.onPressChange);
  }

  void _handlePressEnd() {
    if (_modifiedPointerActivation) return;
    updatePressState(false, widget.onPressChange);
  }

  void _handlePressCancel() {
    final modified = _modifiedPointerActivation;
    _modifiedPointerActivation = false;
    if (!modified) updatePressState(false, widget.onPressChange);
  }

  void _clearInteractionStates() {
    final endedPress = updateState(WidgetState.pressed, false, rebuild: false);
    final endedHover = updateState(WidgetState.hovered, false, rebuild: false);
    final endedFocus = updateState(WidgetState.focused, false, rebuild: false);
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

    final wasEnabled = oldWidget.enabled;
    if (wasEnabled == widget._effectiveEnabled) return;

    updateDisabledState(!widget._effectiveEnabled, rebuild: false);
    if (!widget._effectiveEnabled) _clearInteractionStates();
  }

  Widget _buildLink(launcher.FollowLink? followLink) {
    final isEnabled = widget._effectiveEnabled;
    final semanticLabel = widget.semanticLabel;
    final hasSemanticLabel = semanticLabel?.trim().isNotEmpty ?? false;
    final pointerActivation = isEnabled
        ? () => _handlePointerActivation(followLink!)
        : null;
    final semanticActivation = isEnabled
        ? () {
            // Flutter web converts a trusted DOM click on the semantics anchor
            // into SemanticsAction.tap. Preserve the browser-owned modified
            // click while keeping assistive-technology taps ordinary.
            if (_isModifiedWebClick) {
              _handleModifiedActivation(followLink!);
            } else {
              _handleOrdinaryActivation(followLink!);
            }
          }
        : null;
    Widget result = GestureDetector(
      onTapDown: isEnabled ? _handlePressStart : null,
      onTapUp: isEnabled ? (_) => _handlePressEnd() : null,
      onTapCancel: isEnabled ? _handlePressCancel : null,
      onTap: pointerActivation,
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
        onTap: semanticActivation,
        child: result,
      );
    }

    result = NakedFocusableDetector(
      key: _contentKey,
      enabled: isEnabled,
      autofocus: widget.autofocus,
      canRequestFocus: isEnabled,
      includeSemantics: !widget.excludeSemantics,
      restoreHoverOnEnable: true,
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
      actions: NakedIntentActions.link.actions(
        onPressed: () => _handleOrdinaryActivation(followLink!),
      ),
      debugLabel: 'NakedLink',
      child: result,
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final Widget result;
    if (widget._effectiveEnabled) {
      result = launcher.Link(
        uri: widget.linkUrl,
        builder: (context, followLink) => _buildLink(followLink),
      );
    } else {
      result = _buildLink(null);
    }

    return widget.excludeSemantics ? ExcludeSemantics(child: result) : result;
  }
}
