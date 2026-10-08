import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../data/models/clip.dart';
import '../../../data/models/connector.dart';
import '../../annotation/geometry/eraser_geometry.dart';
import '../controllers/board_controller.dart';
import 'selection_geometry.dart';

/// Pure geometry for connector handles/anchors/curve-shape - no widget
/// imports, unit-tested directly (see
/// test/features/board/connector_geometry_test.dart), same convention as
/// ClipGeometry/SnapGeometry/FrameGeometry.
class ConnectorGeometry {
  ConnectorGeometry._();

  /// Screen-space hit radius for a side-midpoint handle - reuses
  /// ClipGeometry's constant rather than duplicating the magic number.
  static const double handleHitRadius = ClipGeometry.handleHitRadius;
  static const double handleVisualSize = 8;

  /// Minimum/maximum orthogonal-route stub length (board units) pushed out
  /// from each anchor along its direction before the route turns, so very
  /// close clips still read as a visible elbow and very far clips don't
  /// grow an absurdly long stub.
  static const double _minStubLength = 16;
  static const double _maxStubLength = 40;

  static Offset _boardToScreen(Offset boardPoint, BoardViewState view) {
    return boardPoint * view.scale + view.panOffset;
  }

  /// Board-space midpoint of [clip]'s [side] edge, accounting for rotation.
  static Offset sideMidpointBoard(BoardClip clip, ConnectorSide side) {
    final center = ClipGeometry.clipCenter(clip);
    final local = switch (side) {
      ConnectorSide.top => Offset(clip.x + clip.width / 2, clip.y),
      ConnectorSide.right => Offset(
        clip.x + clip.width,
        clip.y + clip.height / 2,
      ),
      ConnectorSide.bottom => Offset(
        clip.x + clip.width / 2,
        clip.y + clip.height,
      ),
      ConnectorSide.left => Offset(clip.x, clip.y + clip.height / 2),
    };
    return ClipGeometry.rotatePoint(local, center, clip.rotation);
  }

  /// Board-space outward unit normal of [clip]'s [side] edge, rotated with
  /// the clip (rotating the direction vector around the origin, not the
  /// clip's center - a normal is a direction, not a point).
  static Offset outwardNormal(BoardClip clip, ConnectorSide side) {
    final local = switch (side) {
      ConnectorSide.top => const Offset(0, -1),
      ConnectorSide.right => const Offset(1, 0),
      ConnectorSide.bottom => const Offset(0, 1),
      ConnectorSide.left => const Offset(-1, 0),
    };
    return ClipGeometry.rotatePoint(local, Offset.zero, clip.rotation);
  }

  /// Screen-space positions of all 4 edge-midpoint handles for [clip] -
  /// mirrors ClipGeometry.handleScreenPositions.
  static Map<ConnectorSide, Offset> handleScreenPositions(
    BoardClip clip,
    BoardViewState view,
  ) {
    return {
      for (final side in ConnectorSide.values)
        side: _boardToScreen(sideMidpointBoard(clip, side), view),
    };
  }

  /// Which handle (if any) of [clip] is under screen-space [screenPoint] -
  /// mirrors ClipGeometry.hitTestHandle. Only meaningful when [clip] is the
  /// sole selected clip and a text clip - callers are responsible for that
  /// gating.
  static ConnectorSide? hitTestHandle(
    BoardClip clip,
    BoardViewState view,
    Offset screenPoint,
  ) {
    for (final entry in handleScreenPositions(clip, view).entries) {
      if ((entry.value - screenPoint).distance <= handleHitRadius) {
        return entry.key;
      }
    }
    return null;
  }

  /// The nearest point on [clip]'s (rotated) rectangle boundary to
  /// arbitrary board-space [boardPoint], plus which side it landed on -
  /// used to compute a connector's dynamically-recomputed target anchor
  /// every frame. Un-rotates [boardPoint] into the clip's local frame
  /// first (same technique as ClipGeometry.pointInClip), finds the
  /// nearest boundary point there, then rotates the result back.
  ///
  /// Accepted approximation: when the local point sits exactly on a
  /// corner's outside diagonal, the side attribution ties are broken by
  /// whichever axis clamped further - a cosmetic corner-case affecting
  /// only the target-end arrowhead's exact angle, not the anchor position
  /// itself.
  static ({Offset point, ConnectorSide side}) nearestBoundaryAnchor(
    BoardClip clip,
    Offset boardPoint,
  ) {
    final center = ClipGeometry.clipCenter(clip);
    final local = ClipGeometry.rotatePoint(boardPoint, center, -clip.rotation);
    final rect = Rect.fromLTWH(clip.x, clip.y, clip.width, clip.height);

    Offset localResult;
    ConnectorSide side;
    if (!rect.contains(local)) {
      final clampedX = local.dx.clamp(rect.left, rect.right);
      final clampedY = local.dy.clamp(rect.top, rect.bottom);
      localResult = Offset(clampedX, clampedY);
      final dxOvershoot = (local.dx - clampedX).abs();
      final dyOvershoot = (local.dy - clampedY).abs();
      if (dxOvershoot >= dyOvershoot) {
        side = clampedX == rect.left ? ConnectorSide.left : ConnectorSide.right;
      } else {
        side = clampedY == rect.top ? ConnectorSide.top : ConnectorSide.bottom;
      }
    } else {
      final dLeft = local.dx - rect.left;
      final dRight = rect.right - local.dx;
      final dTop = local.dy - rect.top;
      final dBottom = rect.bottom - local.dy;
      final minD = math.min(math.min(dLeft, dRight), math.min(dTop, dBottom));
      if (minD == dLeft) {
        localResult = Offset(rect.left, local.dy);
        side = ConnectorSide.left;
      } else if (minD == dRight) {
        localResult = Offset(rect.right, local.dy);
        side = ConnectorSide.right;
      } else if (minD == dTop) {
        localResult = Offset(local.dx, rect.top);
        side = ConnectorSide.top;
      } else {
        localResult = Offset(local.dx, rect.bottom);
        side = ConnectorSide.bottom;
      }
    }
    return (
      point: ClipGeometry.rotatePoint(localResult, center, clip.rotation),
      side: side,
    );
  }

  static double _stubLength(Offset a, Offset b) {
    return ((a - b).distance * 0.5).clamp(_minStubLength, _maxStubLength);
  }

  /// Rounds an arbitrary (possibly rotated) direction vector to the
  /// nearest of the 4 board-space cardinal directions - whichever axis
  /// has the larger-magnitude component wins, snapped to its sign. Lets
  /// [routeBoard] stay strictly axis-aligned ("90-degree angle shifts")
  /// even when an anchor's true outward normal is diagonal because its
  /// clip is rotated; the anchor *point* itself stays exactly correct -
  /// only the very first/last segment's direction is approximated this
  /// way, which is visually identical to the true normal for the common
  /// unrotated case and a reasonable approximation otherwise.
  static Offset _snapToCardinal(Offset direction) {
    if (direction.dx.abs() >= direction.dy.abs()) {
      return Offset(direction.dx >= 0 ? 1 : -1, 0);
    }
    return Offset(0, direction.dy >= 0 ? 1 : -1);
  }

  /// [boardPoint] expressed as a fraction (0-1 on each axis, clamped) of
  /// [clip]'s own width/height, in its local unrotated frame - lets a
  /// connector's target anchor be stored as "a specific spot on this
  /// clip's surface" rather than always the nearest boundary point. Same
  /// un-rotate-into-local-frame technique as [nearestBoundaryAnchor].
  static Offset relativePointInClip(BoardClip clip, Offset boardPoint) {
    final center = ClipGeometry.clipCenter(clip);
    final local = ClipGeometry.rotatePoint(boardPoint, center, -clip.rotation);
    final relX = clip.width == 0
        ? 0.0
        : ((local.dx - clip.x) / clip.width).clamp(0.0, 1.0);
    final relY = clip.height == 0
        ? 0.0
        : ((local.dy - clip.y) / clip.height).clamp(0.0, 1.0);
    return Offset(relX, relY);
  }

  /// The inverse of [relativePointInClip]: the board-space point at
  /// fraction [rel] of [clip]'s width/height.
  static Offset pointFromRelative(BoardClip clip, Offset rel) {
    final local = Offset(
      clip.x + rel.dx * clip.width,
      clip.y + rel.dy * clip.height,
    );
    final center = ClipGeometry.clipCenter(clip);
    return ClipGeometry.rotatePoint(local, center, clip.rotation);
  }

  /// The board-space, axis-aligned polyline of an orthogonal ("elbow")
  /// connector from [fromClip]'s fixed [fromSide] to [toClip] - a
  /// flowchart-style route of straight horizontal/vertical segments only,
  /// turning in 90-degree steps (actual corner rounding happens at paint
  /// time, in screen space - see `ConnectorPainter`). When [toRelX]/
  /// [toRelY] are both given, the target anchor is that exact surface
  /// point ([pointFromRelative]); otherwise it falls back to the nearest
  /// boundary point ([nearestBoundaryAnchor]) - same two cases
  /// `bezierBoard` used to handle, unchanged.
  ///
  /// Construction: each anchor is pushed out a short "stub" along its own
  /// direction ([_snapToCardinal]-ed to a cardinal axis), then the two
  /// stub points are connected by a pure Manhattan path - a 2-bend "Z"
  /// through the shared axis's midpoint when both directions are on the
  /// same axis (both horizontal or both vertical), or a single-bend "L"
  /// when they're on perpendicular axes. This always produces a valid
  /// orthogonal polyline for any relative position/direction combination
  /// - not always the visually shortest possible route in unusual
  /// configurations (e.g. near-overlapping clips), but never a broken or
  /// diagonal one.
  static List<Offset> routeBoard({
    required BoardClip fromClip,
    required ConnectorSide fromSide,
    required BoardClip toClip,
    double? toRelX,
    double? toRelY,
  }) {
    final p0 = sideMidpointBoard(fromClip, fromSide);

    final Offset p1;
    Offset d1Source;
    if (toRelX != null && toRelY != null) {
      p1 = pointFromRelative(toClip, Offset(toRelX, toRelY));
      final toP0 = p0 - p1;
      d1Source = toP0.distance == 0
          ? const Offset(0, -1)
          : toP0 / toP0.distance;
    } else {
      final target = nearestBoundaryAnchor(toClip, p0);
      p1 = target.point;
      d1Source = outwardNormal(toClip, target.side);
    }

    final d0 = _snapToCardinal(outwardNormal(fromClip, fromSide));
    final d1 = _snapToCardinal(d1Source);
    final d0Horizontal = d0.dx != 0;
    final d1Horizontal = d1.dx != 0;

    var stub = _stubLength(p0, p1);
    if (d0 == -d1) {
      // The two anchors face directly toward each other (e.g. a clip's
      // right edge connecting to another clip's left edge just beside
      // it). Letting the stub push either anchor more than halfway across
      // the real gap between them would make the two stub points cross -
      // the route would overshoot past one anchor before doubling back
      // toward the other, instead of a clean elbow. Re-derive the stub
      // from the actual gap along the shared axis so it can never exceed
      // that halfway point.
      final axisGap = d0Horizontal
          ? (p1.dx - p0.dx) * d0.dx
          : (p1.dy - p0.dy) * d0.dy;
      stub = math.max(0.0, math.min(stub, axisGap / 2));
    }
    final s0 = p0 + d0 * stub;
    final s1 = p1 + d1 * stub;

    final bends = <Offset>[];
    if (d0Horizontal == d1Horizontal) {
      if (d0Horizontal) {
        final midX = (s0.dx + s1.dx) / 2;
        bends.addAll([Offset(midX, s0.dy), Offset(midX, s1.dy)]);
      } else {
        final midY = (s0.dy + s1.dy) / 2;
        bends.addAll([Offset(s0.dx, midY), Offset(s1.dx, midY)]);
      }
    } else {
      bends.add(d0Horizontal ? Offset(s1.dx, s0.dy) : Offset(s0.dx, s1.dy));
    }

    final points = [p0, s0, ...bends, s1, p1];
    final result = <Offset>[];
    for (final point in points) {
      if (result.isEmpty || result.last != point) result.add(point);
    }
    return result;
  }

  /// Whether [screenPoint] comes within [handleHitRadius] of the polyline
  /// [points] (already screen-space) - a direct
  /// `EraserGeometry.strokeNearPoint` call, no sampling needed since an
  /// orthogonal route already *is* a polyline (unlike the old cubic
  /// bezier, which had to be sampled into one first).
  static bool hitTestRoute(List<Offset> points, Offset screenPoint) {
    return EraserGeometry.strokeNearPoint(points, screenPoint, handleHitRadius);
  }
}
