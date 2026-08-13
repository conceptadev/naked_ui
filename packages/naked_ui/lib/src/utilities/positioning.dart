import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The preferred side of an anchor on which to place an overlay.
enum OverlaySide {
  /// Place the overlay above the anchor.
  top,

  /// Place the overlay to the right of the anchor.
  right,

  /// Place the overlay below the anchor.
  bottom,

  /// Place the overlay to the left of the anchor.
  left,
}

/// The cross-axis alignment of an overlay relative to its anchor.
enum OverlayAlignment {
  /// Align the logical start edges.
  start,

  /// Center the overlay on the anchor's cross axis.
  center,

  /// Align the logical end edges.
  end,
}

/// Configuration for Radix-shaped anchored-overlay positioning.
@immutable
class OverlayPositionConfig {
  /// Creates overlay positioning configuration.
  const OverlayPositionConfig({
    this.side = OverlaySide.bottom,
    this.alignment = OverlayAlignment.start,
    this.sideOffset = 0,
    this.alignmentOffset = 0,
    this.collisionPadding = EdgeInsets.zero,
    this.avoidCollisions = true,
  }) : assert(sideOffset > double.negativeInfinity),
       assert(sideOffset < double.infinity),
       assert(alignmentOffset > double.negativeInfinity),
       assert(alignmentOffset < double.infinity);

  /// The preferred side of the anchor.
  final OverlaySide side;

  /// The overlay's cross-axis alignment relative to the anchor.
  ///
  /// For top and bottom placements, start and end follow [TextDirection].
  /// For left and right placements, start is top and end is bottom.
  final OverlayAlignment alignment;

  /// Distance between the anchor and overlay along the main axis.
  final double sideOffset;

  /// Additional cross-axis offset after [alignment] is applied.
  ///
  /// For top and bottom placements, positive values move toward logical end.
  /// For left and right placements, positive values move downward.
  final double alignmentOffset;

  /// Insets from the available overlay bounds used for collision handling.
  final EdgeInsets collisionPadding;

  /// Whether the overlay may flip and shift to remain within available bounds.
  final bool avoidCollisions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayPositionConfig &&
          side == other.side &&
          alignment == other.alignment &&
          sideOffset == other.sideOffset &&
          alignmentOffset == other.alignmentOffset &&
          collisionPadding == other.collisionPadding &&
          avoidCollisions == other.avoidCollisions;

  @override
  int get hashCode => Object.hash(
    side,
    alignment,
    sideOffset,
    alignmentOffset,
    collisionPadding,
    avoidCollisions,
  );
}

/// The resolved overlay placement after collision handling.
@immutable
class OverlayPlacement {
  /// Creates a resolved placement.
  const OverlayPlacement({
    required this.side,
    required this.alignment,
    required this.offset,
    required this.wasFlipped,
    required this.wasShifted,
  });

  /// The side on which the overlay was ultimately placed.
  final OverlaySide side;

  /// The requested cross-axis alignment.
  final OverlayAlignment alignment;

  /// The resolved top-left offset in the overlay's coordinate space.
  final Offset offset;

  /// Whether collision handling selected the opposite of the preferred side.
  final bool wasFlipped;

  /// Whether collision handling shifted the overlay within the viewport.
  final bool wasShifted;

  /// Returns the resolved placement that most tightly encloses [context].
  static OverlayPlacement of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_OverlayPlacementScope>();
    assert(scope != null, 'OverlayPlacement.of() called outside an overlay.');

    return scope!.placement;
  }

  /// Returns the nearest resolved placement, if one exists.
  static OverlayPlacement? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_OverlayPlacementScope>()
      ?.placement;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayPlacement &&
          side == other.side &&
          alignment == other.alignment &&
          offset == other.offset &&
          wasFlipped == other.wasFlipped &&
          wasShifted == other.wasShifted;

  @override
  int get hashCode =>
      Object.hash(side, alignment, offset, wasFlipped, wasShifted);
}

class _OverlayPlacementScope extends InheritedWidget {
  const _OverlayPlacementScope({required this.placement, required super.child});

  final OverlayPlacement placement;

  @override
  bool updateShouldNotify(_OverlayPlacementScope oldWidget) =>
      placement != oldWidget.placement;
}

/// Positions an overlay relative to an anchor rectangle.
class OverlayPositioner extends StatefulWidget {
  /// Creates a positioner for [child] relative to [targetRect].
  const OverlayPositioner({
    super.key,
    required this.targetRect,
    this.positioning = const OverlayPositionConfig(),
    this.onPlacementChanged,
    required this.child,
  });

  /// The anchor rectangle in the overlay's coordinate space.
  final Rect targetRect;

  /// Side, alignment, offset, and collision configuration for the overlay.
  final OverlayPositionConfig positioning;

  /// Called after layout when the resolved placement changes.
  final ValueChanged<OverlayPlacement>? onPlacementChanged;

  /// The overlay content to position.
  ///
  /// Descendants can read the current resolved result with
  /// [OverlayPlacement.of].
  final Widget child;

  @override
  State<OverlayPositioner> createState() => _OverlayPositionerState();
}

class _OverlayPositionerState extends State<OverlayPositioner> {
  late OverlayPlacement _placement = _initialPlacement(widget.positioning);
  OverlayPlacement? _pendingPlacement;
  bool _hasReportedPlacement = false;

  static OverlayPlacement _initialPlacement(OverlayPositionConfig config) =>
      OverlayPlacement(
        side: config.side,
        alignment: config.alignment,
        offset: Offset.zero,
        wasFlipped: false,
        wasShifted: false,
      );

  @override
  void didUpdateWidget(covariant OverlayPositioner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.positioning.side != oldWidget.positioning.side ||
        widget.positioning.alignment != oldWidget.positioning.alignment) {
      _placement = _initialPlacement(widget.positioning);
    }
  }

  void _reportPlacement(OverlayPlacement placement) {
    if ((_hasReportedPlacement && placement == _placement) ||
        placement == _pendingPlacement) {
      return;
    }
    _pendingPlacement = placement;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = _pendingPlacement;
      _pendingPlacement = null;
      if (next == null) return;
      final isFirstReport = !_hasReportedPlacement;
      _hasReportedPlacement = true;
      final changed = next != _placement;
      if (changed) setState(() => _placement = next);
      if (!isFirstReport && !changed) return;
      widget.onPlacementChanged?.call(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _OverlayPositionerDelegate(
        targetRect: widget.targetRect,
        positioning: widget.positioning,
        textDirection: Directionality.of(context),
        onPlacement: _reportPlacement,
      ),
      child: _OverlayPlacementScope(placement: _placement, child: widget.child),
    );
  }
}

class _OverlayPositionerDelegate extends SingleChildLayoutDelegate {
  const _OverlayPositionerDelegate({
    required this.targetRect,
    required this.positioning,
    required this.textDirection,
    required this.onPlacement,
  });

  final Rect targetRect;
  final OverlayPositionConfig positioning;
  final TextDirection textDirection;
  final ValueChanged<OverlayPlacement> onPlacement;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final placement = resolveOverlayPlacement(
      targetRect: targetRect,
      overlaySize: childSize,
      boundsSize: size,
      positioning: positioning,
      textDirection: textDirection,
    );
    onPlacement(placement);

    return placement.offset;
  }

  @override
  bool shouldRelayout(_OverlayPositionerDelegate oldDelegate) =>
      targetRect != oldDelegate.targetRect ||
      positioning != oldDelegate.positioning ||
      textDirection != oldDelegate.textDirection ||
      onPlacement != oldDelegate.onPlacement;
}

/// Resolves an anchored overlay position, including collision flip and shift.
OverlayPlacement resolveOverlayPlacement({
  required Rect targetRect,
  required Size overlaySize,
  required Size boundsSize,
  required OverlayPositionConfig positioning,
  required TextDirection textDirection,
}) {
  final preferredOffset = _positionForSide(
    side: positioning.side,
    alignment: positioning.alignment,
    targetRect: targetRect,
    overlaySize: overlaySize,
    sideOffset: positioning.sideOffset,
    alignmentOffset: positioning.alignmentOffset,
    textDirection: textDirection,
  );

  if (!positioning.avoidCollisions) {
    return OverlayPlacement(
      side: positioning.side,
      alignment: positioning.alignment,
      offset: preferredOffset,
      wasFlipped: false,
      wasShifted: false,
    );
  }

  final bounds = _collisionBounds(
    boundsSize,
    overlaySize,
    positioning.collisionPadding,
  );
  final oppositeSide = _opposite(positioning.side);
  final oppositeOffset = _positionForSide(
    side: oppositeSide,
    alignment: positioning.alignment,
    targetRect: targetRect,
    overlaySize: overlaySize,
    sideOffset: positioning.sideOffset,
    alignmentOffset: positioning.alignmentOffset,
    textDirection: textDirection,
  );
  final preferredOverflow = _mainAxisOverflow(
    positioning.side,
    preferredOffset,
    bounds,
  );
  final oppositeOverflow = _mainAxisOverflow(
    oppositeSide,
    oppositeOffset,
    bounds,
  );
  final shouldFlip =
      preferredOverflow > 0 && oppositeOverflow < preferredOverflow;
  final resolvedSide = shouldFlip ? oppositeSide : positioning.side;
  final unshiftedOffset = shouldFlip ? oppositeOffset : preferredOffset;
  final shiftedOffset = Offset(
    unshiftedOffset.dx.clamp(bounds.minX, bounds.maxX),
    unshiftedOffset.dy.clamp(bounds.minY, bounds.maxY),
  );

  return OverlayPlacement(
    side: resolvedSide,
    alignment: positioning.alignment,
    offset: shiftedOffset,
    wasFlipped: shouldFlip,
    wasShifted: shiftedOffset != unshiftedOffset,
  );
}

Offset _positionForSide({
  required OverlaySide side,
  required OverlayAlignment alignment,
  required Rect targetRect,
  required Size overlaySize,
  required double sideOffset,
  required double alignmentOffset,
  required TextDirection textDirection,
}) {
  final isHorizontalPlacement =
      side == OverlaySide.top || side == OverlaySide.bottom;
  final crossPosition = isHorizontalPlacement
      ? _horizontalAlignmentPosition(
              alignment,
              targetRect,
              overlaySize.width,
              textDirection,
            ) +
            alignmentOffset * (textDirection == TextDirection.ltr ? 1 : -1)
      : _verticalAlignmentPosition(alignment, targetRect, overlaySize.height) +
            alignmentOffset;

  return switch (side) {
    OverlaySide.top => Offset(
      crossPosition,
      targetRect.top - overlaySize.height - sideOffset,
    ),
    OverlaySide.right => Offset(targetRect.right + sideOffset, crossPosition),
    OverlaySide.bottom => Offset(crossPosition, targetRect.bottom + sideOffset),
    OverlaySide.left => Offset(
      targetRect.left - overlaySize.width - sideOffset,
      crossPosition,
    ),
  };
}

double _horizontalAlignmentPosition(
  OverlayAlignment alignment,
  Rect targetRect,
  double overlayWidth,
  TextDirection textDirection,
) {
  final start = textDirection == TextDirection.ltr
      ? targetRect.left
      : targetRect.right - overlayWidth;
  final end = textDirection == TextDirection.ltr
      ? targetRect.right - overlayWidth
      : targetRect.left;

  return switch (alignment) {
    OverlayAlignment.start => start,
    OverlayAlignment.center => targetRect.center.dx - overlayWidth / 2,
    OverlayAlignment.end => end,
  };
}

double _verticalAlignmentPosition(
  OverlayAlignment alignment,
  Rect targetRect,
  double overlayHeight,
) => switch (alignment) {
  OverlayAlignment.start => targetRect.top,
  OverlayAlignment.center => targetRect.center.dy - overlayHeight / 2,
  OverlayAlignment.end => targetRect.bottom - overlayHeight,
};

OverlaySide _opposite(OverlaySide side) => switch (side) {
  OverlaySide.top => OverlaySide.bottom,
  OverlaySide.right => OverlaySide.left,
  OverlaySide.bottom => OverlaySide.top,
  OverlaySide.left => OverlaySide.right,
};

({double minX, double maxX, double minY, double maxY}) _collisionBounds(
  Size boundsSize,
  Size overlaySize,
  EdgeInsets padding,
) {
  final minX = padding.left;
  final minY = padding.top;

  return (
    minX: minX,
    maxX: math.max(minX, boundsSize.width - padding.right - overlaySize.width),
    minY: minY,
    maxY: math.max(
      minY,
      boundsSize.height - padding.bottom - overlaySize.height,
    ),
  );
}

double _mainAxisOverflow(
  OverlaySide side,
  Offset offset,
  ({double minX, double maxX, double minY, double maxY}) bounds,
) => switch (side) {
  OverlaySide.top => math.max(0, bounds.minY - offset.dy),
  OverlaySide.right => math.max(0, offset.dx - bounds.maxX),
  OverlaySide.bottom => math.max(0, offset.dy - bounds.maxY),
  OverlaySide.left => math.max(0, bounds.minX - offset.dx),
};

/// Clamps an overlay's top-left position to its available layout bounds.
///
/// Retained as a low-level utility for callers that already have a physical
/// offset. New anchored overlays should use [resolveOverlayPlacement].
Offset clampOverlayPosition(
  Offset overlayTopLeft, {
  required Size overlaySize,
  required Size boundsSize,
}) {
  final maxX = math.max(0.0, boundsSize.width - overlaySize.width);
  final maxY = math.max(0.0, boundsSize.height - overlaySize.height);

  return Offset(
    overlayTopLeft.dx.clamp(0.0, maxX),
    overlayTopLeft.dy.clamp(0.0, maxY),
  );
}
