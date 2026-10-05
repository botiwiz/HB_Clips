import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/geometry/image_pan_zoom_geometry.dart';
import 'package:hb_clips/features/board/geometry/page_crop_settings.dart';

void main() {
  group('clampPageCropZoom', () {
    test('never goes below the epsilon floor', () {
      expect(clampPageCropZoom(0.0), 0.001);
      expect(clampPageCropZoom(-5), 0.001);
    });

    test('has no ceiling, unlike per-image crop', () {
      expect(clampPageCropZoom(100), 100);
    });

    test('passes through an in-range value unchanged', () {
      expect(clampPageCropZoom(0.3), 0.3);
    });
  });

  group('applyPageCropPanDelta', () {
    test('dragging right decreases panX when the content overflows the '
        'page (same direction as ImagePanZoomGeometry.applyPanDelta)', () {
      final result = applyPageCropPanDelta(
        Offset.zero,
        const Offset(10, 0),
        const Offset(100, 100), // positive = content bigger than page
      );
      expect(result.dx, lessThan(0));
    });

    test('dragging right INCREASES panX when the content is smaller than '
        'the page - the sign flips so the net on-screen effect stays the '
        'same direction (see the rendered-position test below)', () {
      final result = applyPageCropPanDelta(
        Offset.zero,
        const Offset(10, 0),
        const Offset(-100, -100), // negative = content smaller than page
      );
      expect(result.dx, greaterThan(0));
    });

    test('the on-screen rendered position moves by exactly the drag '
        'distance regardless of whether overflow is positive or negative '
        '- the actual bug this function fixes (pan used to go dead once '
        'overflow was floored to 0 below cover-fit)', () {
      // Mirrors _PageCropEditorState's own visibleLeft/renderedLeft
      // formula exactly: renderedLeft = -(rawOverflow/2)*(1+panX).
      double renderedLeft(double rawOverflowX, double panX) =>
          -(rawOverflowX / 2) * (1 + panX);

      for (final rawOverflowX in [200.0, -100.0]) {
        const startPan = Offset(0.05, 0);
        const delta = Offset(10, 0);
        final before = renderedLeft(rawOverflowX, startPan.dx);
        final after = applyPageCropPanDelta(
          startPan,
          delta,
          Offset(rawOverflowX, 1), // Y axis unused here
        );
        final afterRendered = renderedLeft(rawOverflowX, after.dx);
        expect(
          afterRendered - before,
          closeTo(delta.dx, 1e-9),
          reason: 'rawOverflowX=$rawOverflowX',
        );
      }
    });

    test('clamps to [-1, 1] even for a huge delta', () {
      final result = applyPageCropPanDelta(
        Offset.zero,
        const Offset(-10000, 10000),
        const Offset(100, 100),
      );
      expect(result.dx, 1.0);
      expect(result.dy, -1.0);
    });

    test('an axis with exactly zero raw overflow is left unchanged '
        '(divide-by-zero guard, not a UX gate)', () {
      final result = applyPageCropPanDelta(
        const Offset(0.3, 0.0),
        const Offset(50, 50),
        const Offset(0, -200), // zero overflow on X only
      );
      expect(result.dx, closeTo(0.3, 1e-9));
      expect(result.dy, isNot(closeTo(0.0, 1e-9)));
    });
  });

  group('zoomPageCropTowardPoint', () {
    test('keeps the point under the cursor fixed when zooming in on '
        'content bigger than the page', () {
      const cover = Size(1000, 800);
      const pageSize = Size(500, 500);
      const crop = PageCropSettings(zoom: 1.0, panX: 0, panY: 0);
      const pointer = Offset(300, 300);
      const oldZoom = 1.0;
      const newZoom = 1.1;

      final newPan = zoomPageCropTowardPoint(
        crop: crop,
        oldZoom: oldZoom,
        newZoom: newZoom,
        pointerPageSpace: pointer,
        cover: cover,
        pageSize: pageSize,
      );

      final newScaled = ImagePanZoomGeometry.scaledSize(cover, newZoom);
      final newRawOverflowX = newScaled.width - pageSize.width;
      final newRawOverflowY = newScaled.height - pageSize.height;
      final newRenderedLeft = -(newRawOverflowX / 2) * (1 + newPan.dx);
      final newRenderedTop = -(newRawOverflowY / 2) * (1 + newPan.dy);

      // The same fraction of content (computed from the OLD render)
      // should land back exactly under the pointer at the new zoom.
      const oldScaled = Size(1000, 800);
      const oldRenderedLeft = -250.0; // -(500/2)*(1+0)
      const oldRenderedTop = -150.0; // -(300/2)*(1+0)
      final fracX = (pointer.dx - oldRenderedLeft) / oldScaled.width;
      final fracY = (pointer.dy - oldRenderedTop) / oldScaled.height;

      expect(
        newRenderedLeft + fracX * newScaled.width,
        closeTo(pointer.dx, 1e-6),
      );
      expect(
        newRenderedTop + fracY * newScaled.height,
        closeTo(pointer.dy, 1e-6),
      );
    });

    test('keeps the point under the cursor fixed when zooming out further '
        'on content already smaller than the page', () {
      const cover = Size(1000, 800);
      const pageSize = Size(500, 500);
      const crop = PageCropSettings(zoom: 0.3, panX: 0.2, panY: -0.1);
      const pointer = Offset(150, 130);
      const oldZoom = 0.3;
      const newZoom = 0.27;

      final newPan = zoomPageCropTowardPoint(
        crop: crop,
        oldZoom: oldZoom,
        newZoom: newZoom,
        pointerPageSpace: pointer,
        cover: cover,
        pageSize: pageSize,
      );

      final oldScaled = ImagePanZoomGeometry.scaledSize(cover, oldZoom);
      final oldRawOverflowX = oldScaled.width - pageSize.width;
      final oldRawOverflowY = oldScaled.height - pageSize.height;
      final oldRenderedLeft = -(oldRawOverflowX / 2) * (1 + crop.panX);
      final oldRenderedTop = -(oldRawOverflowY / 2) * (1 + crop.panY);
      final fracX = (pointer.dx - oldRenderedLeft) / oldScaled.width;
      final fracY = (pointer.dy - oldRenderedTop) / oldScaled.height;

      final newScaled = ImagePanZoomGeometry.scaledSize(cover, newZoom);
      final newRawOverflowX = newScaled.width - pageSize.width;
      final newRawOverflowY = newScaled.height - pageSize.height;
      final newRenderedLeft = -(newRawOverflowX / 2) * (1 + newPan.dx);
      final newRenderedTop = -(newRawOverflowY / 2) * (1 + newPan.dy);

      expect(
        newRenderedLeft + fracX * newScaled.width,
        closeTo(pointer.dx, 1e-6),
      );
      expect(
        newRenderedTop + fracY * newScaled.height,
        closeTo(pointer.dy, 1e-6),
      );
    });

    test('an axis whose new raw overflow is exactly zero leaves that '
        "axis's pan unchanged rather than dividing by zero", () {
      const cover = Size(500, 500);
      const pageSize = Size(500, 500);
      const crop = PageCropSettings(zoom: 0.5, panX: 0.4, panY: 0.1);

      final newPan = zoomPageCropTowardPoint(
        crop: crop,
        oldZoom: 0.5,
        newZoom: 1.0, // scaled == pageSize exactly -> raw overflow 0
        pointerPageSpace: const Offset(250, 250),
        cover: cover,
        pageSize: pageSize,
      );

      expect(newPan.dx, closeTo(0.4, 1e-9));
      expect(newPan.dy, closeTo(0.1, 1e-9));
    });
  });
}
