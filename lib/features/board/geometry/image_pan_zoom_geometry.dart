import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../core/constants.dart';

/// Pure geometry for panning/zooming an image's content within its fixed
/// on-board frame (double-click a clip to enter this mode) - no widget
/// imports, unit-testable the same way `selection_geometry.dart`/
/// `frame_geometry.dart` are. Shared by `clip_widget.dart` (rendering) and
/// `board_canvas.dart` (drag/scroll gesture handling) so both are
/// guaranteed to agree on exactly what a given pan/zoom value looks like.
class ImagePanZoomGeometry {
  ImagePanZoomGeometry._();

  static double clampZoom(double zoom) => zoom.clamp(1.0, kMaxImageZoom);

  /// Base "cover" size (frame-relative, before zoom) for an image with
  /// aspect ratio [r] inside a [frameWidth] x [frameHeight] frame - the
  /// same effect `BoxFit.cover` has today, derived by factoring [r] out of
  /// `max(frameWidth/imgWidth, frameHeight/imgHeight)`. Always exactly
  /// aspect ratio [r] by construction (`coverW/coverH == r`), so degrades
  /// to `coverW=frameWidth, coverH=frameHeight` exactly when the image's
  /// own aspect already matches the frame's.
  static Size coverSize(double frameWidth, double frameHeight, double r) {
    final coverW = math.max(frameWidth, frameHeight * r);
    final coverH = math.max(frameWidth / r, frameHeight);
    return Size(coverW, coverH);
  }

  /// The image content's final size once [zoom] (already clamped via
  /// [clampZoom]) is applied on top of [cover].
  static Size scaledSize(Size cover, double zoom) {
    return Size(cover.width * zoom, cover.height * zoom);
  }

  /// Board-pixel overflow available to pan across per axis - always >= 0,
  /// since zoom is never below 1.0.
  static Offset overflow(double frameWidth, double frameHeight, Size scaled) {
    return Offset(
      math.max(0, scaled.width - frameWidth),
      math.max(0, scaled.height - frameHeight),
    );
  }

  /// New pan (Flutter `Alignment` convention, -1..1 per axis, 0 = centered)
  /// after dragging [localDelta] board pixels - already un-rotated into
  /// the clip's own local frame - from [startPan], given the current
  /// [overflow] on each axis. Sign is negative for direct-manipulation
  /// "grab and slide": dragging right reveals the image's left side at the
  /// frame's right edge. An axis with zero overflow is left unchanged
  /// regardless of drag, since there's nothing to pan across.
  static Offset applyPanDelta(
    Offset startPan,
    Offset localDelta,
    Offset overflow,
  ) {
    var panX = startPan.dx;
    var panY = startPan.dy;
    if (overflow.dx > 0) {
      panX = (panX - 2 * localDelta.dx / overflow.dx).clamp(-1.0, 1.0);
    }
    if (overflow.dy > 0) {
      panY = (panY - 2 * localDelta.dy / overflow.dy).clamp(-1.0, 1.0);
    }
    return Offset(panX, panY);
  }
}
