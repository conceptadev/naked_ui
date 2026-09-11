import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'utilities/naked_state_scope.dart';
import 'utilities/state.dart';

/// Where a [NakedToastScope] stacks its visible toasts.
///
/// Start and end follow the ambient [Directionality].
enum NakedToastPlacement {
  /// Top edge, start side.
  topStart,

  /// Top edge, centered.
  topCenter,

  /// Top edge, end side.
  topEnd,

  /// Bottom edge, start side.
  bottomStart,

  /// Bottom edge, centered.
  bottomCenter,

  /// Bottom edge, end side.
  bottomEnd;

  bool get _isTop => this == topStart || this == topCenter || this == topEnd;

  CrossAxisAlignment get _crossAxisAlignment => switch (this) {
    topStart || bottomStart => CrossAxisAlignment.start,
    topCenter || bottomCenter => CrossAxisAlignment.center,
    topEnd || bottomEnd => CrossAxisAlignment.end,
  };
}

/// How urgently assistive technology should announce a toast.
enum NakedToastPriority {
  /// Announced when the user is idle, as [SemanticsRole.status].
  polite,

  /// Announced immediately, as [SemanticsRole.alert].
  ///
  /// Reserve for urgent, destructive, or time-sensitive messages.
  assertive,
}

/// Why a toast left the screen or the queue.
enum NakedToastDismissReason {
  /// Its duration elapsed while it was visible and not paused.
  timeout,

  /// The presenter's action was activated.
  action,

  /// The presenter's close control or the Escape key dismissed it.
  close,

  /// A handle, [NakedToastController.dismiss], or
  /// [NakedToastController.clear] dismissed it.
  programmatic,

  /// A request with the same id replaced it.
  replaced,

  /// The pending queue was full.
  queueOverflow,

  /// Its scope was disposed or switched to another controller.
  scopeDisposed,
}

/// An immutable request to show one toast.
///
/// [data] is an opaque payload handed back to the scope's presenter; the
/// primitive never inspects it.
@immutable
final class NakedToastRequest<T> {
  /// Creates a toast request.
  ///
  /// [semanticLabel] must not be blank. A non-null [duration] must be
  /// positive. A persistent request (null [duration]) must be [interactive]
  /// so the user can always dismiss it.
  const NakedToastRequest({
    this.id,
    required this.data,
    required this.semanticLabel,
    this.duration = const Duration(seconds: 4),
    this.priority = NakedToastPriority.polite,
    this.interactive = false,
  });

  /// Stable identity. Showing a request whose id equals a visible or queued
  /// toast replaces that toast in place.
  ///
  /// When null, the controller assigns a unique id.
  final Object? id;

  /// The payload the presenter renders.
  final T data;

  /// The text announced once for this toast.
  final String semanticLabel;

  /// How long the toast stays visible, or null to persist until dismissed.
  final Duration? duration;

  /// Whether the toast is announced as a status or an alert.
  final NakedToastPriority priority;

  /// Whether the presenter renders an action or close control.
  ///
  /// Interactive toasts never auto-dismiss while
  /// [MediaQuery.accessibleNavigationOf] is true.
  final bool interactive;
}

/// A reference to one shown toast request.
abstract interface class NakedToastHandle {
  /// The request id, generated when the request had none.
  Object get id;

  /// Completes exactly once, when this request is dismissed for any reason.
  ///
  /// The toast's exit transition may still be running.
  Future<NakedToastDismissReason> get closed;

  /// Whether [closed] has completed.
  bool get isClosed;

  /// Dismisses this request if it is still visible or queued.
  ///
  /// Does nothing once the request is closed, including after a same-id
  /// replacement.
  void dismiss([
    NakedToastDismissReason reason = NakedToastDismissReason.programmatic,
  ]);
}

/// Owns the visible toasts and the pending queue of one [NakedToastScope].
///
/// A scope creates and disposes its own controller when none is supplied. A
/// supplied controller stays owned by the caller, can be attached to one
/// mounted scope at a time, and is never disposed by the scope.
///
/// The scope's [NakedToastScope.maxVisible] requests are shown in
/// first-in, first-out order. Up to [NakedToastScope.maxQueued] more wait in
/// the same order; when that queue is full, the oldest waiting request is
/// dismissed with [NakedToastDismissReason.queueOverflow]. Waiting requests
/// have no widget, semantics node, or timer.
class NakedToastController<T> extends ChangeNotifier {
  /// Creates a controller that must be attached to a [NakedToastScope] before
  /// [show] is called.
  NakedToastController();

  final List<_ToastEntry<T>> _visible = [];
  final List<_ToastEntry<T>> _pending = [];
  Object? _owner;
  int _maxVisible = 3;
  int _maxQueued = 20;
  bool _appActive = true;
  bool _holdInteractive = false;
  int _nextSerial = 0;

  /// Whether a mounted [NakedToastScope] is using this controller.
  bool get isAttached => _owner != null;

  /// The number of toasts currently on screen, excluding exit transitions.
  int get visibleCount => _visible.length;

  /// The number of requests waiting for a visible slot.
  int get pendingCount => _pending.length;

  _ToastEntry<T>? _entryWithId(Object id) {
    for (final entry in _visible) {
      if (entry.id == id) return entry;
    }
    for (final entry in _pending) {
      if (entry.id == id) return entry;
    }

    return null;
  }

  bool _isVisible(_ToastEntry<T> entry) => _visible.contains(entry);

  bool _shouldCountDown(_ToastEntry<T> entry) {
    return entry.request.duration != null &&
        !entry.hovered &&
        !entry.focused &&
        _appActive &&
        !(_holdInteractive && entry.request.interactive);
  }

  bool _isPaused(_ToastEntry<T> entry) {
    return entry.request.duration != null && !_shouldCountDown(entry);
  }

  // Pausing cancels the countdown and resuming restarts the full duration, so a
  // toast never vanishes right after the user stops interacting with it.
  void _syncTimer(_ToastEntry<T> entry) {
    if (!_isVisible(entry) || !_shouldCountDown(entry)) {
      entry.cancelTimer();

      return;
    }
    entry.timer ??= Timer(entry.request.duration!, () {
      entry.timer = null;
      if (_isVisible(entry)) _remove(entry, NakedToastDismissReason.timeout);
    });
  }

  void _promote() {
    while (_visible.length < _maxVisible && _pending.isNotEmpty) {
      final entry = _pending.removeAt(0);
      _visible.add(entry);
      _syncTimer(entry);
    }
  }

  void _remove(_ToastEntry<T> entry, NakedToastDismissReason reason) {
    entry.cancelTimer();
    if (_visible.remove(entry)) {
      _promote();
    } else {
      _pending.remove(entry);
    }
    entry.handle._complete(reason);
    notifyListeners();
  }

  void _dismissHandle(_ToastHandle<T> handle, NakedToastDismissReason reason) {
    final entry = _entryWithId(handle.id);
    if (entry == null || !identical(entry.handle, handle)) return;
    _remove(entry, reason);
  }

  void _checkCanMutate(String method) {
    if (_owner == null) {
      throw StateError(
        'NakedToastController<$T>.$method() was called while the controller '
        'is not attached to a mounted NakedToastScope<$T>. Pass the '
        'controller to a NakedToastScope that stays mounted for as long as '
        'toasts are shown.',
      );
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      throw FlutterError.fromParts([
        ErrorSummary(
          'NakedToastController<$T>.$method() was called during build, '
          'layout, or paint.',
        ),
        ErrorHint(
          'Show toasts from an event callback, or schedule the call with '
          'WidgetsBinding.instance.addPostFrameCallback.',
        ),
      ]);
    }
  }

  static void _validate(NakedToastRequest<Object?> request) {
    if (request.semanticLabel.trim().isEmpty) {
      throw ArgumentError.value(
        request.semanticLabel,
        'semanticLabel',
        'must not be blank',
      );
    }
    final duration = request.duration;
    if (duration != null && duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be positive');
    }
    if (duration == null && !request.interactive) {
      throw ArgumentError(
        'A persistent toast (null duration) must be interactive so the user '
            'can dismiss it.',
        'interactive',
      );
    }
  }

  void _attach(
    Object owner, {
    required int maxVisible,
    required int maxQueued,
  }) {
    if (_owner != null && !identical(_owner, owner)) {
      throw StateError(
        'NakedToastController<$T> is already attached to another mounted '
        'NakedToastScope. A controller can drive one scope at a time.',
      );
    }
    _owner = owner;
    _configure(maxVisible: maxVisible, maxQueued: maxQueued);
  }

  void _detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    final closing = [..._visible, ..._pending];
    _visible.clear();
    _pending.clear();
    for (final entry in closing) {
      entry.cancelTimer();
      entry.handle._complete(NakedToastDismissReason.scopeDisposed);
    }
    _appActive = true;
    _holdInteractive = false;
  }

  // Called from the scope's didUpdateWidget; changes become visible in the
  // scope's following build, so listeners are not notified mid-build.
  void _configure({required int maxVisible, required int maxQueued}) {
    _maxVisible = maxVisible;
    _maxQueued = maxQueued;
    _promote();
    while (_pending.length > _maxQueued) {
      final entry = _pending.removeAt(0);
      entry.handle._complete(NakedToastDismissReason.queueOverflow);
    }
  }

  void _setAppActive(bool value) {
    if (_appActive == value) return;
    _appActive = value;
    _visible.forEach(_syncTimer);
  }

  void _setHoldInteractive(bool value) {
    if (_holdInteractive == value) return;
    _holdInteractive = value;
    _visible.forEach(_syncTimer);
  }

  void _setHovered(_ToastEntry<T> entry, bool value) {
    entry.hovered = value;
    _syncTimer(entry);
  }

  void _setFocused(_ToastEntry<T> entry, bool value) {
    entry.focused = value;
    _syncTimer(entry);
  }

  /// Shows [request], or queues it when every visible slot is taken.
  ///
  /// If a visible or queued toast has an equal non-null id, that toast is
  /// updated in place, its previous handle closes with
  /// [NakedToastDismissReason.replaced], and its lifetime restarts.
  ///
  /// Throws a [StateError] when the controller is not attached, a
  /// [FlutterError] when called during build, layout, or paint, and an
  /// [ArgumentError] when [request] is invalid.
  NakedToastHandle show(NakedToastRequest<T> request) {
    _checkCanMutate('show');
    _validate(request);

    if (request.id case final Object id) {
      final existing = _entryWithId(id);
      if (existing != null) {
        final previous = existing.handle;
        existing
          ..request = request
          ..handle = _ToastHandle<T>(id, this)
          ..cancelTimer();
        _syncTimer(existing);
        previous._complete(NakedToastDismissReason.replaced);
        notifyListeners();

        return existing.handle;
      }
    }

    final serial = _nextSerial++;
    final entry = _ToastEntry<T>(
      request: request,
      handle: _ToastHandle<T>(request.id ?? _GeneratedToastId(serial), this),
      serial: serial,
    );
    if (_visible.length < _maxVisible) {
      _visible.add(entry);
      _syncTimer(entry);
    } else if (_maxQueued == 0) {
      entry.handle._complete(NakedToastDismissReason.queueOverflow);

      return entry.handle;
    } else {
      if (_pending.length >= _maxQueued) {
        _pending
            .removeAt(0)
            .handle
            ._complete(NakedToastDismissReason.queueOverflow);
      }
      _pending.add(entry);
    }
    notifyListeners();

    return entry.handle;
  }

  /// Dismisses the visible or queued toast with [id].
  ///
  /// Returns whether a toast was dismissed. Returns false when the
  /// controller is detached, because detaching already closed every toast.
  bool dismiss(
    Object id, [
    NakedToastDismissReason reason = NakedToastDismissReason.programmatic,
  ]) {
    final entry = _entryWithId(id);
    if (entry == null) return false;
    _remove(entry, reason);

    return true;
  }

  /// Dismisses every visible and queued toast with
  /// [NakedToastDismissReason.programmatic].
  void clear() {
    if (_visible.isEmpty && _pending.isEmpty) return;
    final closing = [..._visible, ..._pending];
    _visible.clear();
    _pending.clear();
    for (final entry in closing) {
      entry.cancelTimer();
      entry.handle._complete(NakedToastDismissReason.programmatic);
    }
    notifyListeners();
  }
}

final class _GeneratedToastId {
  const _GeneratedToastId(this.serial);

  final int serial;

  @override
  String toString() => 'NakedToast#$serial';
}

final class _ToastHandle<T> implements NakedToastHandle {
  _ToastHandle(this.id, this._controller);

  @override
  final Object id;
  final NakedToastController<T> _controller;
  final Completer<NakedToastDismissReason> _completer = Completer();

  void _complete(NakedToastDismissReason reason) {
    if (!_completer.isCompleted) _completer.complete(reason);
  }

  @override
  Future<NakedToastDismissReason> get closed => _completer.future;

  @override
  bool get isClosed => _completer.isCompleted;

  @override
  void dismiss([
    NakedToastDismissReason reason = NakedToastDismissReason.programmatic,
  ]) {
    if (isClosed) return;
    _controller._dismissHandle(this, reason);
  }
}

final class _ToastEntry<T> {
  _ToastEntry({
    required this.request,
    required this.handle,
    required this.serial,
  });

  NakedToastRequest<T> request;
  _ToastHandle<T> handle;

  /// Keys the rendered item; survives same-id replacement, never reused.
  final int serial;
  Timer? timer;
  bool hovered = false;
  bool focused = false;

  Object get id => handle.id;

  void cancelTimer() {
    timer?.cancel();
    timer = null;
  }
}

/// The state of one visible toast, handed to [NakedToastScope.toastBuilder].
///
/// [isHovered] and [isFocused] report pointer hover and focus anywhere inside
/// the toast.
class NakedToastState<T> extends NakedState {
  /// Creates an immutable snapshot of one toast.
  NakedToastState({
    required super.states,
    required this.id,
    required this.data,
    required this.priority,
    required this.duration,
    required this.isPaused,
    required this.isExiting,
    required void Function(NakedToastDismissReason reason) onDismiss,
  }) : _onDismiss = onDismiss;

  /// The request id.
  final Object id;

  /// The request payload.
  final T data;

  /// Whether the toast is announced as a status or an alert.
  final NakedToastPriority priority;

  /// The configured lifetime, or null when persistent.
  final Duration? duration;

  /// Whether the countdown is suspended by hover, focus, app lifecycle, or
  /// accessible navigation. Always false for persistent toasts.
  final bool isPaused;

  /// Whether the toast was dismissed and is running its exit transition.
  final bool isExiting;

  final void Function(NakedToastDismissReason reason) _onDismiss;

  /// Returns the nearest [NakedToastState] provided by [NakedStateScope].
  static NakedToastState<T> of<T>(BuildContext context) =>
      NakedState.of(context);

  /// Returns the nearest [NakedToastState], if one is available.
  static NakedToastState<T>? maybeOf<T>(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Dismisses this toast. Presenters pass
  /// [NakedToastDismissReason.action] from their action control.
  void dismiss([
    NakedToastDismissReason reason = NakedToastDismissReason.close,
  ]) => _onDismiss(reason);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedToastState<T> &&
        statesEqual(other) &&
        other.id == id &&
        other.data == data &&
        other.priority == priority &&
        other.duration == duration &&
        other.isPaused == isPaused &&
        other.isExiting == isExiting;
  }

  @override
  int get hashCode => Object.hash(
    statesHashCode,
    id,
    data,
    priority,
    duration,
    isPaused,
    isExiting,
  );
}

/// Builds the visuals for one toast.
///
/// [animation] runs from zero to one on entrance and back to zero on exit. It
/// jumps when [MediaQuery.disableAnimationsOf] is true.
typedef NakedToastBuilder<T> =
    Widget Function(
      BuildContext context,
      NakedToastState<T> toast,
      Animation<double> animation,
    );

/// Hosts a queue of nonmodal notifications without visual style.
///
/// Place one scope below the app's [Overlay] in a subtree that stays mounted,
/// such as `MaterialApp.home`, a persistent router shell, or the child of
/// [Overlay.wrap]. Toasts render through a single [OverlayPortal], so they
/// inherit [Directionality], [MediaQuery], and theme state from the scope's
/// position and update live when those change.
///
/// Show toasts with [NakedToastScope.of] or an attached
/// [NakedToastController]. Showing a toast never moves focus.
///
/// Each visible toast is one semantics node with [SemanticsRole.status] or
/// [SemanticsRole.alert] and the request's
/// [NakedToastRequest.semanticLabel]. Presenters should exclude visual text
/// that repeats that label from semantics and keep action and close controls
/// as separate button nodes.
///
/// A visible toast pauses its countdown while hovered, while focus is inside
/// it, and while the app is not resumed; resuming restarts the full duration.
/// Escape dismisses the toast that contains focus.
class NakedToastScope<T> extends StatefulWidget {
  /// Creates a headless toast host.
  const NakedToastScope({
    super.key,
    this.controller,
    this.placement = NakedToastPlacement.bottomEnd,
    this.maxVisible = 3,
    this.maxQueued = 20,
    this.inset = const EdgeInsetsDirectional.all(24),
    this.gap = 12,
    this.animationStyle = const AnimationStyle(
      curve: Curves.easeOutCubic,
      duration: Duration(milliseconds: 180),
      reverseDuration: Duration(milliseconds: 120),
    ),
    required this.toastBuilder,
    required this.child,
  });

  /// An optional caller-owned controller.
  final NakedToastController<T>? controller;

  /// The screen edge and side the stack grows from.
  ///
  /// The newest toast sits nearest the edge.
  final NakedToastPlacement placement;

  /// How many toasts can be on screen at once. At least one.
  final int maxVisible;

  /// How many requests can wait for a visible slot. Zero or more.
  final int maxQueued;

  /// Space between the stack and the safe area's edges.
  final EdgeInsetsGeometry inset;

  /// Space between stacked toasts. Zero or more.
  final double gap;

  /// The entrance and exit curves and durations.
  final AnimationStyle animationStyle;

  /// Builds each visible toast.
  final NakedToastBuilder<T> toastBuilder;

  /// The app content the toasts appear over.
  final Widget child;

  /// Returns the controller of the nearest [NakedToastScope] of type [T].
  ///
  /// Does not register a dependency, so it is safe to call from event
  /// callbacks. Throws a [FlutterError] when no scope is found.
  static NakedToastController<T> of<T>(BuildContext context) {
    final controller = maybeOf<T>(context);
    if (controller == null) {
      throw FlutterError.fromParts([
        ErrorSummary(
          'NakedToastScope.of<$T>() was called with a context that does not '
          'contain a NakedToastScope<$T>.',
        ),
        ErrorHint(
          'Place a NakedToastScope<$T> below the app Overlay in a subtree that '
          'stays mounted, for example:\n'
          '  MaterialApp(home: NakedToastScope<$T>(toastBuilder: ..., '
          'child: Shell()))',
        ),
        context.describeElement('The context used was'),
      ]);
    }

    return controller;
  }

  /// Returns the controller of the nearest [NakedToastScope] of type [T], or
  /// null when there is none.
  static NakedToastController<T>? maybeOf<T>(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_NakedToastInherited<T>>()
        ?.controller;
  }

  @override
  State<NakedToastScope<T>> createState() {
    assert(maxVisible >= 1, 'maxVisible must be at least one');
    assert(maxQueued >= 0, 'maxQueued must not be negative');
    assert(gap >= 0, 'gap must not be negative');

    return _NakedToastScopeState<T>();
  }
}

class _NakedToastInherited<T> extends InheritedWidget {
  const _NakedToastInherited({required this.controller, required super.child});

  final NakedToastController<T> controller;

  @override
  bool updateShouldNotify(_NakedToastInherited<T> oldWidget) =>
      controller != oldWidget.controller;
}

final class _RenderedToast<T> {
  _RenderedToast(this.entry);

  final _ToastEntry<T> entry;
  bool exiting = false;
}

class _NakedToastScopeState<T> extends State<NakedToastScope<T>> {
  NakedToastController<T>? _ownedController;
  late NakedToastController<T> _controller;
  late final AppLifecycleListener _lifecycleListener;
  final OverlayPortalController _portalController = OverlayPortalController();

  /// Visible toasts plus toasts still running their exit transition, oldest
  /// first.
  final List<_RenderedToast<T>> _rendered = [];

  static bool _isActive(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? (_ownedController = NakedToastController<T>());
    _attach();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleLifecycleChange,
    );
    _controller._setAppActive(
      _isActive(WidgetsBinding.instance.lifecycleState),
    );
    _portalController.show();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller._setHoldInteractive(
      MediaQuery.maybeAccessibleNavigationOf(context) ?? false,
    );
  }

  @override
  void didUpdateWidget(covariant NakedToastScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextController = widget.controller ?? _ownedController;
    if (nextController != _controller) {
      _detach();
      _rendered.clear();
      if (widget.controller == null) {
        _controller = _ownedController = NakedToastController<T>();
      } else {
        _ownedController?.dispose();
        _ownedController = null;
        _controller = widget.controller!;
      }
      _attach();
      _controller
        .._setAppActive(_isActive(WidgetsBinding.instance.lifecycleState))
        .._setHoldInteractive(
          MediaQuery.maybeAccessibleNavigationOf(context) ?? false,
        );
    } else if (widget.maxVisible != oldWidget.maxVisible ||
        widget.maxQueued != oldWidget.maxQueued) {
      _controller._configure(
        maxVisible: widget.maxVisible,
        maxQueued: widget.maxQueued,
      );
      _syncRendered();
    }
  }

  void _attach() {
    _controller
      .._attach(
        this,
        maxVisible: widget.maxVisible,
        maxQueued: widget.maxQueued,
      )
      ..addListener(_handleControllerChanged);
    _syncRendered();
  }

  void _detach() {
    _controller
      ..removeListener(_handleControllerChanged)
      .._detach(this);
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(_syncRendered);
  }

  void _handleLifecycleChange(AppLifecycleState state) {
    _controller._setAppActive(_isActive(state));
    if (mounted) setState(() {});
  }

  void _syncRendered() {
    final visible = _controller._visible;
    for (final rendered in _rendered) {
      if (!rendered.exiting && !visible.contains(rendered.entry)) {
        rendered.exiting = true;
      }
    }
    for (final entry in visible) {
      if (!_rendered.any((rendered) => identical(rendered.entry, entry))) {
        _rendered.add(_RenderedToast(entry));
      }
    }
  }

  void _handleExited(_ToastEntry<T> entry) {
    if (!mounted) return;
    setState(() {
      _rendered.removeWhere(
        (rendered) => rendered.exiting && identical(rendered.entry, entry),
      );
    });
  }

  Widget _buildRegion(BuildContext context) {
    if (_rendered.isEmpty) return const SizedBox.shrink();

    final placement = widget.placement;
    final inset = widget.inset.resolve(Directionality.of(context));
    final padding = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    final keyboard = MediaQuery.maybeViewInsetsOf(context) ?? EdgeInsets.zero;

    final items = [
      for (final rendered in _rendered)
        _NakedToastItem<T>(
          key: ValueKey<int>(rendered.entry.serial),
          controller: _controller,
          entry: rendered.entry,
          exiting: rendered.exiting,
          animationStyle: widget.animationStyle,
          onExited: _handleExited,
          builder: widget.toastBuilder,
        ),
    ];

    return Stack(
      children: [
        Positioned(
          left: inset.left + padding.left,
          top: placement._isTop ? inset.top + padding.top : null,
          right: inset.right + padding.right,
          bottom: placement._isTop
              ? null
              : inset.bottom + math.max(padding.bottom, keyboard.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: placement._crossAxisAlignment,
            spacing: widget.gap,
            children: placement._isTop ? items.reversed.toList() : items,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _detach();
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      if (Overlay.maybeOf(context) == null) {
        throw FlutterError.fromParts([
          ErrorSummary('NakedToastScope<$T> requires an Overlay ancestor.'),
          ErrorHint(
            'Place the scope below the app Overlay, for example in '
            'MaterialApp.home or WidgetsApp.home, or wrap it with '
            'Overlay.wrap.',
          ),
        ]);
      }

      return true;
    }());

    return _NakedToastInherited<T>(
      controller: _controller,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: _buildRegion,
        child: widget.child,
      ),
    );
  }
}

class _NakedToastItem<T> extends StatefulWidget {
  const _NakedToastItem({
    super.key,
    required this.controller,
    required this.entry,
    required this.exiting,
    required this.animationStyle,
    required this.onExited,
    required this.builder,
  });

  final NakedToastController<T> controller;
  final _ToastEntry<T> entry;
  final bool exiting;
  final AnimationStyle animationStyle;
  final ValueChanged<_ToastEntry<T>> onExited;
  final NakedToastBuilder<T> builder;

  @override
  State<_NakedToastItem<T>> createState() => _NakedToastItemState<T>();
}

class _NakedToastItemState<T> extends State<_NakedToastItem<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late CurvedAnimation _animation;
  FocusNode? _focusToRestore;
  bool _hovered = false;
  bool _focusWithin = false;
  bool _entered = false;

  AnimationStyle get _style => widget.animationStyle;

  CurvedAnimation _createAnimation() {
    final curve = _style.curve ?? Curves.easeOutCubic;

    return CurvedAnimation(
      parent: _animationController,
      curve: curve,
      reverseCurve: _style.reverseCurve ?? curve.flipped,
    );
  }

  void _applyDurations() {
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final forward = _style.duration ?? const Duration(milliseconds: 180);
    _animationController
      ..duration = disabled ? Duration.zero : forward
      ..reverseDuration = disabled
          ? Duration.zero
          : _style.reverseDuration ?? forward;
  }

  void _dismiss(NakedToastDismissReason reason) {
    if (widget.exiting) return;
    widget.entry.handle.dismiss(reason);
  }

  void _handleHover(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    if (!widget.exiting) widget.controller._setHovered(widget.entry, value);
  }

  void _handleFocusChange(bool value) {
    if (_focusWithin == value) return;
    setState(() => _focusWithin = value);
    if (!widget.exiting) widget.controller._setFocused(widget.entry, value);
  }

  void _beginExit() {
    if (_focusWithin) {
      final target = _focusToRestore;
      if (target != null && target.context != null && target.canRequestFocus) {
        target.requestFocus();
      }
    }
    _animationController.reverse().whenCompleteOrCancel(() {
      if (mounted && widget.exiting) widget.onExited(widget.entry);
    });
  }

  @override
  void initState() {
    super.initState();
    _focusToRestore = FocusManager.instance.primaryFocus;
    _animationController = AnimationController(vsync: this);
    _animation = _createAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyDurations();
    if (!_entered) {
      _entered = true;
      if (widget.exiting) {
        _beginExit();
      } else {
        _animationController.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _NakedToastItem<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationStyle != oldWidget.animationStyle) {
      _animation.dispose();
      _animation = _createAnimation();
      _applyDurations();
    }
    if (widget.exiting && !oldWidget.exiting) _beginExit();
  }

  @override
  void dispose() {
    _animation.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final request = entry.request;
    final toast = NakedToastState<T>(
      states: {
        if (_hovered) WidgetState.hovered,
        if (_focusWithin) WidgetState.focused,
      },
      id: entry.id,
      data: request.data,
      priority: request.priority,
      duration: request.duration,
      isPaused: !widget.exiting && widget.controller._isPaused(entry),
      isExiting: widget.exiting,
      onDismiss: _dismiss,
    );

    Widget result = NakedStateScope<NakedToastState<T>>(
      value: toast,
      child: Builder(
        builder: (context) => widget.builder(context, toast, _animation),
      ),
    );
    result = Semantics(
      container: true,
      explicitChildNodes: true,
      role: request.priority == NakedToastPriority.assertive
          ? SemanticsRole.alert
          : SemanticsRole.status,
      label: request.semanticLabel,
      child: result,
    );
    result = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _handleFocusChange,
      child: result,
    );
    result = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _dismiss(NakedToastDismissReason.close),
      },
      child: result,
    );
    result = MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: result,
    );

    return IgnorePointer(
      ignoring: widget.exiting,
      child: ExcludeSemantics(
        excluding: widget.exiting,
        child: ExcludeFocus(excluding: widget.exiting, child: result),
      ),
    );
  }
}
