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

  /// Top-left of the rendered (scaled) content, relative to [frame]'s own
  /// top-left - the inverse of the `Alignment(panX, panY)` math
  /// `ImagePanZoomFrame`'s `OverflowBox` applies: alignment -1 puts the
  /// content's edge flush with the frame's edge (offset 0); alignment 1
  /// pulls it fully the other way (offset -overflow).
  static Offset _contentTopLeft(
    double panX,
    double panY,
    Offset overflow,
  ) {
    return Offset(
      -overflow.dx * (panX + 1) / 2,
      -overflow.dy * (panY + 1) / 2,
    );
  }

  /// PureRef-style in-place crop: [subRect] is a candidate new frame - in
  /// the same coordinate space as [frame] (board-space, already un-
  /// rotated into the clip's own local frame if it's rotated - see
  /// `board_canvas.dart`'s only caller) - clamped to [frame]'s own bounds
  /// first, since a crop can never extend past the image's current
  /// bounds any more than PureRef's own crop handles can. Returns null if
  /// the clamped result is smaller than [minSize] on either axis (nothing
  /// meaningful to crop to).
  ///
  /// The returned pan/zoom keep the image content that was visible under
  /// [subRect] visually unchanged - same on-board scale, same crop of the
  /// source picture - the frame just shrinks around it, rather than
  /// resetting to a fresh cover-fit view the way a plain resize would.
  /// [panX]/[panY]/[zoom] are the frame's pan/zoom *before* the crop.
  static ({Rect rect, double panX, double panY, double zoom})? crop({
    required Rect frame,
    required Rect subRect,
    required double aspectRatio,
    required double panX,
    required double panY,
    required double zoom,
    required double minSize,
  }) {
    final clamped = subRect.intersect(frame);
    if (clamped.width < minSize || clamped.height < minSize) return null;

    final zoom0 = clampZoom(zoom);
    final cover0 = coverSize(frame.width, frame.height, aspectRatio);
    final scaled0 = scaledSize(cover0, zoom0);
    final overflow0 = overflow(frame.width, frame.height, scaled0);
    final contentTL0 = _contentTopLeft(panX, panY, overflow0);

    // Desired content top-left, relative to the NEW frame's own origin
    // (the clamped sub-rect's top-left) - unchanged in absolute board
    // terms, just re-expressed against the smaller frame.
    final subLocal = clamped.topLeft - frame.topLeft;
    final newContentTL = contentTL0 - subLocal;

    final cover1 = coverSize(clamped.width, clamped.height, aspectRatio);
    // Solve for the zoom that keeps the content's absolute (board-space)
    // size unchanged - cropping shrinks the viewing window, it doesn't
    // re-zoom the picture. cover0/cover1 both have exactly [aspectRatio]
    // by construction, so either axis gives the same ratio; width is
    // used arbitrarily.
    final zoom1 = clampZoom(scaled0.width / cover1.width);
    final scaled1 = scaledSize(cover1, zoom1);
    final overflow1 = overflow(clamped.width, clamped.height, scaled1);

    double axisPan(double contentTL, double axisOverflow) {
      if (axisOverflow <= 0) return 0.0;
      return (-2 * contentTL / axisOverflow - 1).clamp(-1.0, 1.0);
    }

    return (
      rect: clamped,
      panX: axisPan(newContentTL.dx, overflow1.dx),
      panY: axisPan(newContentTL.dy, overflow1.dy),
      zoom: zoom1,
    );
  }
}
