import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/features/board/geometry/image_pan_zoom_geometry.dart';
import 'package:hb_clips/features/board/geometry/selection_geometry.dart';

void main() {
  group('clampZoom', () {
    test('never goes below 1.0', () {
      expect(ImagePanZoomGeometry.clampZoom(0.2), 1.0);
      expect(ImagePanZoomGeometry.clampZoom(0.999), 1.0);
    });

    test('never exceeds kMaxImageZoom', () {
      expect(ImagePanZoomGeometry.clampZoom(100), kMaxImageZoom);
    });

    test('passes through an in-range value unchanged', () {
      expect(ImagePanZoomGeometry.clampZoom(2.5), 2.5);
    });
  });

  group('coverSize', () {
    test('matches the frame exactly when the image aspect already matches', () {
      // 200x100 frame, aspect ratio 2 - no overflow needed on either axis.
      final cover = ImagePanZoomGeometry.coverSize(200, 100, 2);
      expect(cover.width, closeTo(200, 1e-9));
      expect(cover.height, closeTo(100, 1e-9));
    });

    test('image relatively wider than the frame overflows width only', () {
      // 100x100 frame, image aspect 4 (very wide) - height fills the
      // frame exactly, width overflows.
      final cover = ImagePanZoomGeometry.coverSize(100, 100, 4);
      expect(cover.height, closeTo(100, 1e-9));
      expect(cover.width, greaterThan(100));
      expect(cover.width / cover.height, closeTo(4, 1e-9));
    });

    test('image relatively taller than the frame overflows height only', () {
      // 100x100 frame, image aspect 0.25 (very tall) - width fills the
      // frame exactly, height overflows.
      final cover = ImagePanZoomGeometry.coverSize(100, 100, 0.25);
      expect(cover.width, closeTo(100, 1e-9));
      expect(cover.height, greaterThan(100));
      expect(cover.width / cover.height, closeTo(0.25, 1e-9));
    });
  });

  group('scaledSize / overflow', () {
    test('overflow is zero at zoom=1 when the aspect already matches the frame', () {
      final cover = ImagePanZoomGeometry.coverSize(200, 100, 2);
      final scaled = ImagePanZoomGeometry.scaledSize(cover, 1.0);
      final overflow = ImagePanZoomGeometry.overflow(200, 100, scaled);
      expect(overflow.dx, closeTo(0, 1e-9));
      expect(overflow.dy, closeTo(0, 1e-9));
    });

    test('zooming in creates overflow on both axes when the aspect matches', () {
      final cover = ImagePanZoomGeometry.coverSize(200, 100, 2);
      final scaled = ImagePanZoomGeometry.scaledSize(cover, 2.0);
      final overflow = ImagePanZoomGeometry.overflow(200, 100, scaled);
      expect(overflow.dx, closeTo(200, 1e-9)); // scaled 400 - frame 200
      expect(overflow.dy, closeTo(100, 1e-9)); // scaled 200 - frame 100
    });
  });

  group('applyPanDelta', () {
    test('dragging right decreases panX (reveals the image\'s left side)', () {
      final result = ImagePanZoomGeometry.applyPanDelta(
        Offset.zero,
        const Offset(10, 0),
        const Offset(100, 100),
      );
      expect(result.dx, lessThan(0));
    });

    test('dragging left increases panX', () {
      final result = ImagePanZoomGeometry.applyPanDelta(
        Offset.zero,
        const Offset(-10, 0),
        const Offset(100, 100),
      );
      expect(result.dx, greaterThan(0));
    });

    test('clamps to [-1, 1] even for a huge delta', () {
      final result = ImagePanZoomGeometry.applyPanDelta(
        Offset.zero,
        const Offset(-10000, 10000),
        const Offset(100, 100),
      );
      expect(result.dx, 1.0);
      expect(result.dy, -1.0);
    });

    test('an axis with zero overflow is left unchanged regardless of drag', () {
      final result = ImagePanZoomGeometry.applyPanDelta(
        const Offset(0.3, 0.0),
        const Offset(50, 50),
        const Offset(0, 200), // no overflow on X
      );
      expect(result.dx, closeTo(0.3, 1e-9));
      expect(result.dy, isNot(closeTo(0.0, 1e-9)));
    });

    test('a full-overflow-width drag moves pan exactly one full unit', () {
      // overflow.dx == 100, dragging localDelta.dx == -50 (half the
      // overflow) should move panX by exactly 1.0 (half of the [-1,1] span
      // per the 2/overflow conversion factor), i.e. a -50 drag with 100
      // overflow covers the whole span from center to one edge.
      final result = ImagePanZoomGeometry.applyPanDelta(
        Offset.zero,
        const Offset(-50, 0),
        const Offset(100, 100),
      );
      expect(result.dx, closeTo(1.0, 1e-9));
    });
  });

  group('rotation-aware pan (matches how board_canvas.dart applies it)', () {
    test('a 90-degree-rotated clip maps a horizontal drag to a vertical pan change', () {
      // Un-rotating a purely-horizontal board-space delta by -90 degrees
      // should produce a purely-vertical local delta.
      final localDelta = ClipGeometry.rotatePoint(
        const Offset(10, 0),
        Offset.zero,
        -math.pi / 2,
      );
      expect(localDelta.dx, closeTo(0, 1e-9));
      expect(localDelta.dy, isNot(closeTo(0, 1e-9)));

      final result = ImagePanZoomGeometry.applyPanDelta(
        Offset.zero,
        localDelta,
        const Offset(100, 100),
      );
      expect(result.dx, closeTo(0, 1e-9));
      expect(result.dy, isNot(closeTo(0, 1e-9)));
    });
  });
}
