import 'dart:math' as math;

import 'package:flutter/rendering.dart';
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
    test(
      'overflow is zero at zoom=1 when the aspect already matches the frame',
      () {
        final cover = ImagePanZoomGeometry.coverSize(200, 100, 2);
        final scaled = ImagePanZoomGeometry.scaledSize(cover, 1.0);
        final overflow = ImagePanZoomGeometry.overflow(200, 100, scaled);
        expect(overflow.dx, closeTo(0, 1e-9));
        expect(overflow.dy, closeTo(0, 1e-9));
      },
    );

    test(
      'zooming in creates overflow on both axes when the aspect matches',
      () {
        final cover = ImagePanZoomGeometry.coverSize(200, 100, 2);
        final scaled = ImagePanZoomGeometry.scaledSize(cover, 2.0);
        final overflow = ImagePanZoomGeometry.overflow(200, 100, scaled);
        expect(overflow.dx, closeTo(200, 1e-9)); // scaled 400 - frame 200
        expect(overflow.dy, closeTo(100, 1e-9)); // scaled 200 - frame 100
      },
    );
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

  group('crop', () {
    test(
      'cropping the centered half of a non-panned, non-zoomed image '
      'zooms in 2x, staying centered (pan unchanged)',
      () {
        final result = ImagePanZoomGeometry.crop(
          frame: const Rect.fromLTWH(0, 0, 200, 100),
          subRect: const Rect.fromLTWH(50, 25, 100, 50),
          aspectRatio: 2,
          panX: 0,
          panY: 0,
          zoom: 1,
          minSize: 1,
        );
        expect(result, isNotNull);
        expect(result!.rect, const Rect.fromLTWH(50, 25, 100, 50));
        expect(result.zoom, closeTo(2.0, 1e-9));
        expect(result.panX, closeTo(0, 1e-9));
        expect(result.panY, closeTo(0, 1e-9));
      },
    );

    test('clamps the marquee to the frame\'s own current bounds', () {
      final result = ImagePanZoomGeometry.crop(
        frame: const Rect.fromLTWH(0, 0, 100, 100),
        // Extends well past the frame on every side.
        subRect: const Rect.fromLTWH(-50, -50, 300, 300),
        aspectRatio: 1,
        panX: 0,
        panY: 0,
        zoom: 1,
        minSize: 1,
      );
      expect(result, isNotNull);
      expect(result!.rect, const Rect.fromLTWH(0, 0, 100, 100));
    });

    test('returns null when the clamped region is smaller than minSize', () {
      final result = ImagePanZoomGeometry.crop(
        frame: const Rect.fromLTWH(0, 0, 100, 100),
        subRect: const Rect.fromLTWH(10, 10, 5, 5),
        aspectRatio: 1,
        panX: 0,
        panY: 0,
        zoom: 1,
        minSize: 40,
      );
      expect(result, isNull);
    });

    test('returns null for a marquee that misses the frame entirely', () {
      final result = ImagePanZoomGeometry.crop(
        frame: const Rect.fromLTWH(0, 0, 100, 100),
        subRect: const Rect.fromLTWH(200, 200, 50, 50),
        aspectRatio: 1,
        panX: 0,
        panY: 0,
        zoom: 1,
        minSize: 1,
      );
      expect(result, isNull);
    });

    test(
      'preserves the exact same visual crop of the source image when the '
      'frame already had a non-zero pan/zoom',
      () {
        const frame = Rect.fromLTWH(0, 0, 100, 100);
        const aspectRatio = 1.0;
        const panX0 = 0.5;
        const panY0 = -0.5;
        const zoom0 = 2.0;
        const subRect = Rect.fromLTWH(10, 10, 60, 60);

        // Independently reconstruct the OLD absolute (board-space) top-left
        // of the rendered content, purely from the public cover/scaled/
        // overflow functions and the same Alignment formula
        // ImagePanZoomFrame's OverflowBox uses - not by calling crop().
        Offset absoluteContentTopLeft(
          Rect f,
          double panX,
          double panY,
          double zoom,
        ) {
          final cover = ImagePanZoomGeometry.coverSize(
            f.width,
            f.height,
            aspectRatio,
          );
          final scaled = ImagePanZoomGeometry.scaledSize(
            cover,
            ImagePanZoomGeometry.clampZoom(zoom),
          );
          final overflow = ImagePanZoomGeometry.overflow(
            f.width,
            f.height,
            scaled,
          );
          return f.topLeft +
              Offset(
                -overflow.dx * (panX + 1) / 2,
                -overflow.dy * (panY + 1) / 2,
              );
        }

        Size absoluteContentSize(Rect f, double zoom) {
          final cover = ImagePanZoomGeometry.coverSize(
            f.width,
            f.height,
            aspectRatio,
          );
          return ImagePanZoomGeometry.scaledSize(
            cover,
            ImagePanZoomGeometry.clampZoom(zoom),
          );
        }

        final result = ImagePanZoomGeometry.crop(
          frame: frame,
          subRect: subRect,
          aspectRatio: aspectRatio,
          panX: panX0,
          panY: panY0,
          zoom: zoom0,
          minSize: 1,
        );
        expect(result, isNotNull);
        expect(result!.rect, subRect);

        final oldTopLeft = absoluteContentTopLeft(frame, panX0, panY0, zoom0);
        final newTopLeft = absoluteContentTopLeft(
          result.rect,
          result.panX,
          result.panY,
          result.zoom,
        );
        expect(newTopLeft.dx, closeTo(oldTopLeft.dx, 1e-6));
        expect(newTopLeft.dy, closeTo(oldTopLeft.dy, 1e-6));

        // Zoom wasn't forced against the 1.0..kMaxImageZoom floor/ceiling
        // here, so the content's absolute rendered size - not just its
        // top-left - is preserved exactly too (the crop only moves the
        // viewing window, it doesn't re-zoom the picture).
        final oldSize = absoluteContentSize(frame, zoom0);
        final newSize = absoluteContentSize(result.rect, result.zoom);
        expect(newSize.width, closeTo(oldSize.width, 1e-6));
        expect(newSize.height, closeTo(oldSize.height, 1e-6));
      },
    );

    test(
      'clamps zoom to kMaxImageZoom for an extreme crop instead of '
      'exceeding it',
      () {
        final result = ImagePanZoomGeometry.crop(
          frame: const Rect.fromLTWH(0, 0, 100, 100),
          subRect: const Rect.fromLTWH(47.5, 47.5, 5, 5),
          aspectRatio: 1,
          panX: 0,
          panY: 0,
          zoom: 1,
          minSize: 1,
        );
        expect(result, isNotNull);
        expect(result!.zoom, kMaxImageZoom);
      },
    );
  });

  group('rotation-aware pan (matches how board_canvas.dart applies it)', () {
    test(
      'a 90-degree-rotated clip maps a horizontal drag to a vertical pan change',
      () {
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
      },
    );
  });
}
