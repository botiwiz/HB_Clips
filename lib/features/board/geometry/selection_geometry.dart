import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../core/constants.dart';
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

  /// Minimum width/height floor for a shape clip specifically - far
  /// smaller than [minClipSize], which is a deliberate "don't let a
  /// photo/note shrink to nothing" UX floor that doesn't apply to shapes:
  /// the user should be able to drag a rectangle/ellipse down into a very
  /// thin line-like sliver (e.g. a divider) on either axis. Not a UX
  /// choice itself, just small enough to keep the resize/scale math
  /// well-defined (never exactly 0, which would degenerate several
  /// downstream computations - aspect ratios, scale factors).
  static const double minShapeSize = 1.0;

  /// Rounds [value] to the nearest multiple of [spacing] - used to snap
  /// drag/resize positions and sizes to the board's dot grid.
  static double snap(double value, double spacing) {
    return (value / spacing).round() * spacing;
  }

  static Offset _boardToScreen(Offset boardPoint, BoardViewState view) {
    return boardPoint * view.scale + view.panOffset;
  }

  /// Inverse of [_boardToScreen] - converts a screen-local point (relative
  /// to the board canvas's own render box) back to board space. Exposed
  /// publicly (unlike [_boardToScreen]) so a caller outside
  /// `board_canvas.dart` - e.g. a drag-and-drop gesture ending elsewhere
  /// in the widget tree - can convert a drop point without duplicating
  /// this one-line formula; `board_canvas.dart` keeps its own private
  /// `_screenToBoard` untouched.
  static Offset screenToBoard(Offset screenPoint, BoardViewState view) =>
      (screenPoint - view.panOffset) / view.scale;

  /// Board-space rect for a text-tool placement: a plain click ([moved]
  /// false) gets a rect of [defaultWidth]x[defaultHeight] centered on
  /// [start]; a click-drag gets the dragged rect verbatim, normalized from
  /// [start] to [end] - no minimum-size floor, unlike the "C"+drag
  /// define-frame gesture, since a plain click must still produce
  /// something here and [moved] already distinguishes click from drag.
  static Rect textToolPlacementRect({
    required Offset start,
    required Offset end,
    required bool moved,
    required double defaultWidth,
    required double defaultHeight,
  }) {
    if (!moved) {
      return Rect.fromCenter(
        center: start,
        width: defaultWidth,
        height: defaultHeight,
      );
    }
    return Rect.fromPoints(start, end);
  }

  static BoardClip? findById(List<BoardClip> clips, String id) {
    for (final clip in clips) {
      if (clip.id == id) return clip;
    }
    return null;
  }

  /// Union of every clip's plain axis-aligned rect (rotation ignored
  /// deliberately - callers that need this, like Arrange-selection, reset
  /// rotation to 0 on every clip they touch anyway, so using each clip's
  /// unrotated rect as input is simpler and correct). [clips] must be
  /// non-empty.
  static Rect boardBoundingBox(List<BoardClip> clips) {
    var rect = Rect.fromLTWH(
      clips.first.x,
      clips.first.y,
      clips.first.width,
      clips.first.height,
    );
    for (final clip in clips.skip(1)) {
      rect = rect.expandToInclude(
        Rect.fromLTWH(clip.x, clip.y, clip.width, clip.height),
      );
    }
    return rect;
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

  /// The topmost (highest zIndex) clip among [clips] whose body contains
  /// [boardPoint] (rotation-aware, via [pointInClip]), optionally
  /// restricted by [where]. A small standalone helper for drag-and-drop
  /// style features that need their own hit-testing outside
  /// `board_canvas.dart`'s own gesture handling - NOT a replacement for
  /// that file's private `_hitTestClip` (left untouched to avoid any risk
  /// to already-working click/drag gestures).
  static BoardClip? topmostAt(
    List<BoardClip> clips,
    Offset boardPoint, {
    bool Function(BoardClip clip)? where,
  }) {
    BoardClip? best;
    for (final c in clips) {
      if (where != null && !where(c)) continue;
      if (!pointInClip(boardPoint, c)) continue;
      if (best == null || c.zIndex > best.zIndex) best = c;
    }
    return best;
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
    Offset at(double x, double y) =>
        rotatePoint(Offset(x, y), center, clip.rotation);
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
  static Offset rotateHandleScreenPosition(
    BoardClip clip,
    BoardViewState view,
  ) {
    final center = clipCenter(clip);
    final topCenterBoard = rotatePoint(
      Offset(clip.x + clip.width / 2, clip.y),
      center,
      clip.rotation,
    );
    final centerScreen = _boardToScreen(center, view);
    final topCenterScreen = _boardToScreen(topCenterBoard, view);
    final dir = topCenterScreen - centerScreen;
    final normalized = dir.distance == 0
        ? const Offset(0, -1)
        : dir / dir.distance;
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
    final localPointer = rotatePoint(
      pointerBoard,
      center0,
      -startClip.rotation,
    );

    final anchor = switch (corner) {
      HandleKind.resizeTL => Offset(
        startClip.x + startClip.width,
        startClip.y + startClip.height,
      ),
      HandleKind.resizeTR => Offset(
        startClip.x,
        startClip.y + startClip.height,
      ),
      HandleKind.resizeBR => Offset(startClip.x, startClip.y),
      HandleKind.resizeBL => Offset(startClip.x + startClip.width, startClip.y),
      HandleKind.rotate => throw ArgumentError(
        'resize() called with rotate handle',
      ),
    };

    // Shapes get a much smaller floor than every other clip type - see
    // minShapeSize's doc comment - so they can be resized down into a
    // thin line-like sliver on either axis.
    final floor = startClip.type == ClipType.shape ? minShapeSize : minClipSize;
    final rawRect = Rect.fromPoints(anchor, localPointer);
    final width = rawRect.width < floor ? floor : rawRect.width;
    final height = rawRect.height < floor ? floor : rawRect.height;
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
  /// Snapped to the nearest [kRotationSnapIncrementDegrees] so every
  /// clip's rotate handle moves in fixed steps rather than free-form.
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
    final raw = rotation0 + (angleNow - angle0);
    final stepRadians = kRotationSnapIncrementDegrees * math.pi / 180;
    return (raw / stepRadians).round() * stepRadians;
  }

  /// Applies the same board-space [delta] to every clip's gesture-start
  /// position, for a group move.
  static Map<String, Offset> applyGroupDelta(
    Map<String, Offset> startPositions,
    Offset delta,
  ) {
    return startPositions.map((id, pos) => MapEntry(id, pos + delta));
  }

  /// Screen-space positions of the 4 corners of an unrotated board-space
  /// [rect] - the group-scale equivalent of [handleScreenPositions], for a
  /// selection's bounding box rather than a single clip. No rotate handle:
  /// group scale doesn't offer one.
  static Map<HandleKind, Offset> rectHandleScreenPositions(
    Rect rect,
    BoardViewState view,
  ) {
    return {
      HandleKind.resizeTL: _boardToScreen(rect.topLeft, view),
      HandleKind.resizeTR: _boardToScreen(rect.topRight, view),
      HandleKind.resizeBR: _boardToScreen(rect.bottomRight, view),
      HandleKind.resizeBL: _boardToScreen(rect.bottomLeft, view),
    };
  }

  /// Returns which corner handle (if any) of [rect] is under screen-space
  /// [screenPoint], mirroring [hitTestHandle] but for a bounding box.
  static HandleKind? hitTestRectHandle(
    Rect rect,
    BoardViewState view,
    Offset screenPoint,
  ) {
    for (final entry in rectHandleScreenPositions(rect, view).entries) {
      if ((entry.value - screenPoint).distance <= handleHitRadius) {
        return entry.key;
      }
    }
    return null;
  }

  /// Uniformly scales every clip in [startClips] (gesture-start snapshots,
  /// keyed by id) as a rigid group, anchored at [startGroupRect]'s corner
  /// opposite [corner]. A single scale factor is derived from how far
  /// [pointerBoard] has moved that corner relative to the anchor, along
  /// whichever axis moved proportionally more of the group rect's own
  /// width/height - so the group scales uniformly (locked aspect ratio)
  /// rather than independently per axis like single-clip [resize]. The
  /// factor is then clamped so no clip in the group drops below its own
  /// type's floor on its narrower edge ([minClipSize] normally,
  /// [minShapeSize] for a shape clip - see that constant's doc comment)
  /// every clip is scaled by that same clamped factor so relative spacing
  /// stays proportional even at the floor.
  ///
  /// v1 restriction (enforced by callers, not here): only meaningful when
  /// every clip in [startClips] has rotation == 0 - see
  /// `GroupScaleHandles`'s doc comment for why.
  static Map<String, ({double x, double y, double width, double height})>
  scaleGroup({
    required Map<String, BoardClip> startClips,
    required Rect startGroupRect,
    required HandleKind corner,
    required Offset pointerBoard,
  }) {
    assert(corner != HandleKind.rotate);
    assert(startClips.isNotEmpty);

    final anchor = switch (corner) {
      HandleKind.resizeTL => startGroupRect.bottomRight,
      HandleKind.resizeTR => startGroupRect.bottomLeft,
      HandleKind.resizeBR => startGroupRect.topLeft,
      HandleKind.resizeBL => startGroupRect.topRight,
      HandleKind.rotate => throw ArgumentError(
        'scaleGroup() called with rotate handle',
      ),
    };

    final rawWidth = (pointerBoard.dx - anchor.dx).abs();
    final rawHeight = (pointerBoard.dy - anchor.dy).abs();
    final scaleX = startGroupRect.width == 0
        ? 1.0
        : rawWidth / startGroupRect.width;
    final scaleY = startGroupRect.height == 0
        ? 1.0
        : rawHeight / startGroupRect.height;
    var scale = math.max(scaleX, scaleY);
    if (scale <= 0) scale = 0.01;

    // Each clip is checked against its own type's floor (a shape's is
    // much smaller - see minShapeSize) rather than clamping the whole
    // group by a single shared minEdge/minClipSize pair, so a shape
    // mixed into a group with e.g. a photo doesn't inherit the photo's
    // much larger floor.
    for (final clip in startClips.values) {
      final floor = clip.type == ClipType.shape ? minShapeSize : minClipSize;
      final edge = math.min(clip.width, clip.height);
      if (edge > 0) {
        final requiredScale = floor / edge;
        if (requiredScale > scale) scale = requiredScale;
      }
    }

    return startClips.map((id, clip) {
      final newX = anchor.dx + (clip.x - anchor.dx) * scale;
      final newY = anchor.dy + (clip.y - anchor.dy) * scale;
      return MapEntry(id, (
        x: newX,
        y: newY,
        width: clip.width * scale,
        height: clip.height * scale,
      ));
    });
  }
}
