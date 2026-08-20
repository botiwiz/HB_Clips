import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../data/models/clip.dart';
import '../controllers/board_controller.dart';

enum HandleKind { resizeTL, resizeTR, resizeBR, resizeBL, rotate }

/// Pure geometry for selection/resize/rotate/marquee math - no widget
/// imports, so it's unit-testable without pumping a Flutter engine (see
/// test/features/board/selection_math_test.dart).
class ClipGeometry {
  ClipGeometry._();

  /// Screen-space hit radius for a handle, constant regardless of zoom.
  static const double handleHitRadius = 10;
  static const double handleVisualSize = 8;

  /// How far above the clip's (rotated) top edge the rotate handle sits, in
  /// screen pixels.
  static const double rotateHandleOffset = 28;

  static const double minClipSize = 40;

  static Offset _boardToScreen(Offset boardPoint, BoardViewState view) {
    return boardPoint * view.scale + view.panOffset;
  }

  static BoardClip? findById(List<BoardClip> clips, String id) {
    for (final clip in clips) {
      if (clip.id == id) return clip;
    }
    return null;
  }

  static Offset clipCenter(BoardClip clip) =>
      Offset(clip.x + clip.width / 2, clip.y + clip.height / 2);

  static Offset unrotatedTopLeft(BoardClip clip) => Offset(clip.x, clip.y);

  /// Rotates [point] around [center] by [radians] (standard 2D rotation).
  static Offset rotatePoint(Offset point, Offset center, double radians) {
    if (radians == 0) return point;
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    return Offset(
      center.dx + dx * cosA - dy * sinA,
      center.dy + dx * sinA + dy * cosA,
    );
  }

  /// Whether board-space [point] falls inside [clip], accounting for its
  /// rotation by un-rotating the point into the clip's local (unrotated)
  /// frame before an ordinary axis-aligned contains check.
  static bool pointInClip(Offset point, BoardClip clip) {
    final center = clipCenter(clip);
    final local = rotatePoint(point, center, -clip.rotation);
    final rect = Rect.fromLTWH(clip.x, clip.y, clip.width, clip.height);
    return rect.contains(local);
  }

  /// Whether a board-space marquee rect overlaps [clip]. Deliberately an
  /// axis-aligned bounding-box test even for rotated clips - an accepted
  /// approximation rather than exact rotated-rect intersection.
  static bool marqueeIntersects(Rect marqueeBoardRect, BoardClip clip) {
    final rect = Rect.fromLTWH(clip.x, clip.y, clip.width, clip.height);
    return marqueeBoardRect.overlaps(rect);
  }

  static Map<HandleKind, Offset> _resizeCornersBoard(BoardClip clip) {
    final center = clipCenter(clip);
    Offset at(double x, double y) => rotatePoint(Offset(x, y), center, clip.rotation);
    return {
      HandleKind.resizeTL: at(clip.x, clip.y),
      HandleKind.resizeTR: at(clip.x + clip.width, clip.y),
      HandleKind.resizeBR: at(clip.x + clip.width, clip.y + clip.height),
      HandleKind.resizeBL: at(clip.x, clip.y + clip.height),
    };
  }

  /// Screen-space position of the rotate handle: sits [rotateHandleOffset]
  /// screen pixels beyond the clip's (rotated) top-center edge, along the
  /// direction from the clip's center through that edge - so it visually
  /// orbits with the clip as it rotates.
  static Offset rotateHandleScreenPosition(BoardClip clip, BoardViewState view) {
    final center = clipCenter(clip);
    final topCenterBoard = rotatePoint(
      Offset(clip.x + clip.width / 2, clip.y),
      center,
      clip.rotation,
    );
    final centerScreen = _boardToScreen(center, view);
    final topCenterScreen = _boardToScreen(topCenterBoard, view);
    final dir = topCenterScreen - centerScreen;
    final normalized = dir.distance == 0 ? const Offset(0, -1) : dir / dir.distance;
    return topCenterScreen + normalized * rotateHandleOffset;
  }

  /// Screen-space position of every handle for [clip]: the 4 resize
  /// corners plus the rotate handle. Used both for painting the handles
  /// and for hit-testing them.
  static Map<HandleKind, Offset> handleScreenPositions(
    BoardClip clip,
    BoardViewState view,
  ) {
    final positions = <HandleKind, Offset>{
      for (final entry in _resizeCornersBoard(clip).entries)
        entry.key: _boardToScreen(entry.value, view),
    };
    positions[HandleKind.rotate] = rotateHandleScreenPosition(clip, view);
    return positions;
  }

  /// Returns which handle (if any) of [clip] is under screen-space
  /// [screenPoint], or null if none. Only meaningful when [clip] is the
  /// sole selected clip - callers are responsible for that gating.
  static HandleKind? hitTestHandle(
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

  /// Resizes [startClip] by dragging [corner] to the current board-space
  /// pointer position [pointerBoard], keeping the opposite corner fixed.
  /// [startClip] is the clip's transform at gesture-start (not updated
  /// frame-to-frame) so repeated calls during one drag stay stable rather
  /// than drifting.
  static ({double x, double y, double width, double height}) resize({
    required BoardClip startClip,
    required HandleKind corner,
    required Offset pointerBoard,
  }) {
    assert(corner != HandleKind.rotate);
    final center0 = clipCenter(startClip);
    final localPointer = rotatePoint(pointerBoard, center0, -startClip.rotation);

    final anchor = switch (corner) {
      HandleKind.resizeTL => Offset(
        startClip.x + startClip.width,
        startClip.y + startClip.height,
      ),
      HandleKind.resizeTR => Offset(startClip.x, startClip.y + startClip.height),
      HandleKind.resizeBR => Offset(startClip.x, startClip.y),
      HandleKind.resizeBL => Offset(startClip.x + startClip.width, startClip.y),
      HandleKind.rotate => throw ArgumentError('resize() called with rotate handle'),
    };

    final rawRect = Rect.fromPoints(anchor, localPointer);
    final width = rawRect.width < minClipSize ? minClipSize : rawRect.width;
    final height = rawRect.height < minClipSize ? minClipSize : rawRect.height;
    final anchorIsLeft = (anchor.dx - rawRect.left).abs() < 0.01;
    final anchorIsTop = (anchor.dy - rawRect.top).abs() < 0.01;
    final x = anchorIsLeft ? anchor.dx : anchor.dx - width;
    final y = anchorIsTop ? anchor.dy : anchor.dy - height;

    return (x: x, y: y, width: width, height: height);
  }

  /// New rotation (radians) for a rotate gesture: [rotation0] is the
  /// clip's rotation at gesture-start, [center] its (fixed, gesture-start)
  /// center, and the delta is the change in angle from the pointer's
  /// start position to its current position, both measured from [center].
  ///
  /// Known limitation: because this is delta-based via atan2, a single
  /// pointer-move frame whose angle crosses the +-pi seam can jump instead
  /// of wrapping smoothly. Acceptable at normal mouse sampling rates.
  static double rotate({
    required double rotation0,
    required Offset center,
    required Offset startPointerBoard,
    required Offset currentPointerBoard,
  }) {
    final angle0 = math.atan2(
      startPointerBoard.dy - center.dy,
      startPointerBoard.dx - center.dx,
    );
    final angleNow = math.atan2(
      currentPointerBoard.dy - center.dy,
      currentPointerBoard.dx - center.dx,
    );
    return rotation0 + (angleNow - angle0);
  }

  /// Applies the same board-space [delta] to every clip's gesture-start
  /// position, for a group move.
  static Map<String, Offset> applyGroupDelta(
    Map<String, Offset> startPositions,
    Offset delta,
  ) {
    return startPositions.map((id, pos) => MapEntry(id, pos + delta));
  }
}
