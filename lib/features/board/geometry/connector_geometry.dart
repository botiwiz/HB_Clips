import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../data/models/clip.dart';
import '../../../data/models/connector.dart';
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

  /// Minimum/maximum bezier control-point offset (board units) from each
  /// anchor along its outward normal, so very close clips still read as a
  /// visible curve and very far clips don't balloon into an absurd arc.
  static const double _minControlOffset = 20;
  static const double _maxControlOffset = 120;

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

  static double _controlOffset(Offset a, Offset b) {
    return ((a - b).distance * 0.5).clamp(_minControlOffset, _maxControlOffset);
  }

  /// The 4 board-space points (P0 start anchor, C1, C2, P3 end anchor) of
  /// a cubic bezier connecting [fromClip]'s fixed [fromSide] to the
  /// nearest boundary point on [toClip] - control points are pushed out
  /// along each anchor's own outward normal so the curve reads as a
  /// smooth "leaving/arriving perpendicular to the box edge" arc,
  /// Miro-style, rather than a straight line.
  static ({Offset p0, Offset c1, Offset c2, Offset p3}) bezierBoard({
    required BoardClip fromClip,
    required ConnectorSide fromSide,
    required BoardClip toClip,
  }) {
    final p0 = sideMidpointBoard(fromClip, fromSide);
    final target = nearestBoundaryAnchor(toClip, p0);
    final p3 = target.point;
    final offset = _controlOffset(p0, p3);
    final c1 = p0 + outwardNormal(fromClip, fromSide) * offset;
    final c2 = p3 + outwardNormal(toClip, target.side) * offset;
    return (p0: p0, c1: c1, c2: c2, p3: p3);
  }
}
