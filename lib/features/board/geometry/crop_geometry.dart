import 'package:flutter/rendering.dart';

import '../../../data/models/clip.dart';
import '../controllers/board_controller.dart';
import 'selection_geometry.dart';

enum CropHandleKind { tl, tr, bl, br, top, bottom, left, right }

/// Pure geometry for the crop tool's rectangle - handle positions,
/// hit-testing, and corner/edge dragging - mirroring `ClipGeometry`'s
/// resize math but operating on a rect *within* the clip's local frame
/// (fractional 0..1 of its width/height) instead of the clip's own
/// board-space transform. No widget imports, unit-testable like
/// `selection_geometry.dart` (see test/features/board/crop_math_test.dart).
class CropGeometry {
  CropGeometry._();

  static const double handleHitRadius = 10;
  static const double minCropFraction = 0.05;

  /// The 8 handle positions in board space, *within the clip's local
  /// (unrotated) frame* - i.e. before `clip.rotation` is applied.
  static Map<CropHandleKind, Offset> _localBoardPositions(
    BoardClip clip,
    Rect cropRect,
  ) {
    final left = clip.x + cropRect.left * clip.width;
    final top = clip.y + cropRect.top * clip.height;
    final right = clip.x + cropRect.right * clip.width;
    final bottom = clip.y + cropRect.bottom * clip.height;
    final midX = (left + right) / 2;
    final midY = (top + bottom) / 2;
    return {
      CropHandleKind.tl: Offset(left, top),
      CropHandleKind.tr: Offset(right, top),
      CropHandleKind.bl: Offset(left, bottom),
      CropHandleKind.br: Offset(right, bottom),
      CropHandleKind.top: Offset(midX, top),
      CropHandleKind.bottom: Offset(midX, bottom),
      CropHandleKind.left: Offset(left, midY),
      CropHandleKind.right: Offset(right, midY),
    };
  }

  static Map<CropHandleKind, Offset> handleScreenPositions(
    BoardClip clip,
    BoardViewState view,
    Rect cropRect,
  ) {
    final center = ClipGeometry.clipCenter(clip);
    final local = _localBoardPositions(clip, cropRect);
    return local.map((kind, point) {
      final rotated = ClipGeometry.rotatePoint(point, center, clip.rotation);
      final screen = Offset(
        rotated.dx * view.scale + view.panOffset.dx,
        rotated.dy * view.scale + view.panOffset.dy,
      );
      return MapEntry(kind, screen);
    });
  }

  static CropHandleKind? hitTestHandle(
    BoardClip clip,
    BoardViewState view,
    Rect cropRect,
    Offset screenPoint,
  ) {
    final positions = handleScreenPositions(clip, view, cropRect);
    for (final entry in positions.entries) {
      if ((entry.value - screenPoint).distance <= handleHitRadius) {
        return entry.key;
      }
    }
    return null;
  }

  /// Returns a new crop rect after dragging [handle] so the relevant
  /// edge(s) follow [fractionalPointer] (the pointer's position converted
  /// into the clip's own local 0..1 fraction - same conversion used to
  /// attach strokes to a clip). [startRect] is the rect at gesture-start
  /// (not the previous frame's rect) so repeated calls during one drag stay
  /// stable, matching `ClipGeometry.resize`'s convention. Clamped to
  /// [0,1] and to [minCropFraction] minimum size.
  static Rect updateCropRect(
    Rect startRect,
    CropHandleKind handle,
    Offset fractionalPointer,
  ) {
    var left = startRect.left;
    var top = startRect.top;
    var right = startRect.right;
    var bottom = startRect.bottom;

    final px = fractionalPointer.dx.clamp(0.0, 1.0);
    final py = fractionalPointer.dy.clamp(0.0, 1.0);

    switch (handle) {
      case CropHandleKind.tl:
        left = px;
        top = py;
      case CropHandleKind.tr:
        right = px;
        top = py;
      case CropHandleKind.bl:
        left = px;
        bottom = py;
      case CropHandleKind.br:
        right = px;
        bottom = py;
      case CropHandleKind.top:
        top = py;
      case CropHandleKind.bottom:
        bottom = py;
      case CropHandleKind.left:
        left = px;
      case CropHandleKind.right:
        right = px;
    }

    const anchoredLeft = {
      CropHandleKind.left,
      CropHandleKind.tl,
      CropHandleKind.bl,
    };
    const anchoredTop = {
      CropHandleKind.top,
      CropHandleKind.tl,
      CropHandleKind.tr,
    };

    if (right - left < minCropFraction) {
      if (anchoredLeft.contains(handle)) {
        left = right - minCropFraction;
      } else {
        right = left + minCropFraction;
      }
    }
    if (bottom - top < minCropFraction) {
      if (anchoredTop.contains(handle)) {
        top = bottom - minCropFraction;
      } else {
        bottom = top + minCropFraction;
      }
    }

    return Rect.fromLTRB(
      left.clamp(0.0, 1.0),
      top.clamp(0.0, 1.0),
      right.clamp(0.0, 1.0),
      bottom.clamp(0.0, 1.0),
    );
  }
}
