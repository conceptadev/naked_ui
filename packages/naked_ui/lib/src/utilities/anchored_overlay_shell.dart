import 'package:flutter/widgets.dart';

import 'intents.dart';
import 'positioning.dart';

/// Shared overlay shell used by NakedMenu and NakedSelect.
///
/// Wraps a target child with RawMenuAnchor and renders the overlay content
/// positioned relative to the anchor. Handles outside taps, simple keyboard
/// traversal (Esc and Arrow Up/Down), and focus traversal grouping.
class AnchoredOverlayShell extends StatelessWidget {
  /// Creates a shared anchored-overlay shell around [child].
  const AnchoredOverlayShell({
    super.key,
    required this.controller,
    required this.child,
    required this.overlayBuilder,
    this.onOpen,
    this.onClose,
    this.onOpenRequested,
    this.onCloseRequested,
    this.onDismissRequested,
    this.consumeOutsideTaps = true,
    this.useRootOverlay = false,
    this.closeOnClickOutside = true,
    this.triggerFocusNode,
    this.positioningAnchorKey,
    this.positioning = const OverlayPositionConfig(),
  });

  /// The controller that manages overlay visibility.
  final MenuController controller;

  /// The inline target widget (e.g., trigger button).
  final Widget child;

  /// Builds the overlay content shown when open.
  final RawMenuAnchorOverlayBuilder overlayBuilder;

  /// Called when the overlay opens.
  final VoidCallback? onOpen;

  /// Called when the overlay closes.
  final VoidCallback? onClose;

  /// Intercepts open requests. Call `showOverlay` to actually show.
  final RawMenuAnchorOpenRequestedCallback? onOpenRequested;

  /// Intercepts close requests. Call `hideOverlay` to actually hide.
  final RawMenuAnchorCloseRequestedCallback? onCloseRequested;

  /// Handles user-initiated dismissal from Escape or an outside tap.
  ///
  /// Defaults to closing [controller]. Controlled overlays use this hook to
  /// request a state change from their owner instead.
  final VoidCallback? onDismissRequested;

  /// Whether taps outside should be consumed by the anchor region.
  final bool consumeOutsideTaps;

  /// Whether to render in the root overlay.
  final bool useRootOverlay;

  /// Whether clicking outside closes the overlay.
  final bool closeOnClickOutside;

  /// Focus node to return focus to on close.
  final FocusNode? triggerFocusNode;

  /// Optional key for a widget that should anchor positioning instead of
  /// [child]. The keyed widget may live anywhere in the same overlay subtree.
  final GlobalKey? positioningAnchorKey;

  /// Positioning configuration for the overlay.
  final OverlayPositionConfig positioning;

  void _focusBoundary({required bool last}) {
    final current = FocusManager.instance.primaryFocus;
    if (current == null) return;
    final policy = FocusTraversalGroup.maybeOfNode(current);
    if (policy == null) return;
    final target = last
        ? policy.findLastFocus(current, ignoreCurrentFocus: true)
        : policy.findFirstFocus(current, ignoreCurrentFocus: true);
    target?.requestFocus();
  }

  void _moveFocus({required bool forward}) {
    final current = FocusManager.instance.primaryFocus;
    if (current == null) return;
    if (forward) {
      current.nextFocus();
    } else {
      current.previousFocus();
    }
  }

  void _dismiss() {
    final callback = onDismissRequested;
    if (callback == null) {
      controller.close();
    } else {
      callback();
    }
  }

  Rect _resolveAnchorRect(BuildContext context, RawMenuOverlayInfo info) {
    final anchorContext = positioningAnchorKey?.currentContext;
    final anchorBox = anchorContext?.findRenderObject();
    final overlayBox = Overlay.maybeOf(
      context,
      rootOverlay: useRootOverlay,
    )?.context.findRenderObject();
    if (anchorBox is! RenderBox || overlayBox is! RenderBox) {
      return info.anchorRect;
    }
    final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);

    return topLeft & anchorBox.size;
  }

  @override
  Widget build(BuildContext context) {
    return RawMenuAnchor(
      childFocusNode: triggerFocusNode,
      consumeOutsideTaps: consumeOutsideTaps,
      onOpen: onOpen,
      onClose: onClose,
      onOpenRequested: onOpenRequested ?? (_, show) => show(),
      onCloseRequested: onCloseRequested ?? (hide) => hide(),
      useRootOverlay: useRootOverlay,
      controller: controller,
      overlayBuilder: (context, info) {
        final anchorRect = _resolveAnchorRect(context, info);
        final resolvedInfo = anchorRect == info.anchorRect
            ? info
            : RawMenuOverlayInfo(
                anchorRect: anchorRect,
                overlaySize: info.overlaySize,
                tapRegionGroupId: info.tapRegionGroupId,
                position: info.position,
              );
        final overlayChild = overlayBuilder(context, resolvedInfo);

        return OverlayPositioner(
          targetRect: anchorRect,
          positioning: positioning,
          child: TapRegion(
            onTapOutside: closeOnClickOutside ? (event) => _dismiss() : null,
            groupId: resolvedInfo.tapRegionGroupId,
            child: FocusScope(
              child: FocusTraversalGroup(
                child: Shortcuts(
                  shortcuts: NakedIntentActions.menu.shortcuts,
                  child: Actions(
                    actions: NakedIntentActions.menu.actions(
                      onDismiss: _dismiss,
                      onNextFocus: () => _moveFocus(forward: true),
                      onPreviousFocus: () => _moveFocus(forward: false),
                      onFirstFocus: () => _focusBoundary(last: false),
                      onLastFocus: () => _focusBoundary(last: true),
                    ),
                    child: Focus(
                      autofocus: true,
                      canRequestFocus: true,
                      skipTraversal: true,
                      child: overlayChild,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
