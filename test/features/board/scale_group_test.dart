import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/controllers/board_controller.dart';
import 'package:hb_clips/features/board/geometry/selection_geometry.dart';

BoardClip _clip({
  required String id,
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  final now = DateTime(2026);
  return BoardClip(
    id: id,
    boardId: 'board',
    type: ClipType.image,
    x: x,
    y: y,
    width: width,
    height: height,
    rotation: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('rectHandleScreenPositions / hitTestRectHandle', () {
    const view = BoardViewState(panOffset: Offset.zero, scale: 1);

    test('hits each corner of an unrotated rect', () {
      const rect = Rect.fromLTWH(0, 0, 100, 60);
      expect(
        ClipGeometry.hitTestRectHandle(rect, view, const Offset(0, 0)),
        HandleKind.resizeTL,
      );
      expect(
        ClipGeometry.hitTestRectHandle(rect, view, const Offset(100, 0)),
        HandleKind.resizeTR,
      );
      expect(
        ClipGeometry.hitTestRectHandle(rect, view, const Offset(100, 60)),
        HandleKind.resizeBR,
      );
      expect(
        ClipGeometry.hitTestRectHandle(rect, view, const Offset(0, 60)),
        HandleKind.resizeBL,
      );
    });

    test('a point far from every corner misses', () {
      const rect = Rect.fromLTWH(0, 0, 100, 60);
      expect(
        ClipGeometry.hitTestRectHandle(rect, view, const Offset(50, 30)),
        isNull,
      );
    });
  });

  group('scaleGroup', () {
    test('dragging BR outward keeps the opposite (TL) corner anchored', () {
      final a = _clip(id: 'a', x: 0, y: 0, width: 50, height: 60);
      final b = _clip(id: 'b', x: 50, y: 0, width: 50, height: 60);
      final startRect = ClipGeometry.boardBoundingBox([a, b]);
      expect(startRect, const Rect.fromLTWH(0, 0, 100, 60));

      final results = ClipGeometry.scaleGroup(
        startClips: {'a': a, 'b': b},
        startGroupRect: startRect,
        corner: HandleKind.resizeBR,
        pointerBoard: const Offset(200, 120), // 2x in both directions
      );

      final ra = results['a']!;
      final rb = results['b']!;
      // Anchor (TL) stays fixed: clip a's top-left is at the group's TL.
      expect(ra.x, closeTo(0, 1e-9));
      expect(ra.y, closeTo(0, 1e-9));
      expect(ra.width, closeTo(100, 1e-9));
      expect(ra.height, closeTo(120, 1e-9));
      expect(rb.x, closeTo(100, 1e-9));
      expect(rb.y, closeTo(0, 1e-9));
      expect(rb.width, closeTo(100, 1e-9));
      expect(rb.height, closeTo(120, 1e-9));
    });

    test('scaling is uniform: distance between clip centers scales by the same factor', () {
      final a = _clip(id: 'a', x: 0, y: 0, width: 50, height: 60);
      final b = _clip(id: 'b', x: 50, y: 0, width: 50, height: 60);
      final startRect = ClipGeometry.boardBoundingBox([a, b]);
      final startCenterA = Offset(a.x + a.width / 2, a.y + a.height / 2);
      final startCenterB = Offset(b.x + b.width / 2, b.y + b.height / 2);
      final startDistance = (startCenterB - startCenterA).distance;

      final results = ClipGeometry.scaleGroup(
        startClips: {'a': a, 'b': b},
        startGroupRect: startRect,
        corner: HandleKind.resizeBR,
        pointerBoard: const Offset(200, 120), // scale factor 2
      );

      final ra = results['a']!;
      final rb = results['b']!;
      final endCenterA = Offset(ra.x + ra.width / 2, ra.y + ra.height / 2);
      final endCenterB = Offset(rb.x + rb.width / 2, rb.y + rb.height / 2);
      final endDistance = (endCenterB - endCenterA).distance;

      expect(endDistance, closeTo(startDistance * 2, 1e-9));
    });

    test('each of the 4 corners anchors the correct opposite corner', () {
      final a = _clip(id: 'a', x: 0, y: 0, width: 100, height: 60);
      final startRect = ClipGeometry.boardBoundingBox([a]);

      final tl = ClipGeometry.scaleGroup(
        startClips: {'a': a},
        startGroupRect: startRect,
        corner: HandleKind.resizeTL,
        pointerBoard: const Offset(50, 30), // halfway to the BR anchor
      )['a']!;
      expect(tl.x + tl.width, closeTo(100, 1e-9));
      expect(tl.y + tl.height, closeTo(60, 1e-9));

      final tr = ClipGeometry.scaleGroup(
        startClips: {'a': a},
        startGroupRect: startRect,
        corner: HandleKind.resizeTR,
        pointerBoard: const Offset(50, 30),
      )['a']!;
      expect(tr.x, closeTo(0, 1e-9));
      expect(tr.y + tr.height, closeTo(60, 1e-9));

      final br = ClipGeometry.scaleGroup(
        startClips: {'a': a},
        startGroupRect: startRect,
        corner: HandleKind.resizeBR,
        pointerBoard: const Offset(50, 30),
      )['a']!;
      expect(br.x, closeTo(0, 1e-9));
      expect(br.y, closeTo(0, 1e-9));

      final bl = ClipGeometry.scaleGroup(
        startClips: {'a': a},
        startGroupRect: startRect,
        corner: HandleKind.resizeBL,
        pointerBoard: const Offset(50, 30),
      )['a']!;
      expect(bl.x + bl.width, closeTo(100, 1e-9));
      expect(bl.y, closeTo(0, 1e-9));
    });

    test('shrinking clamps the whole group by the same factor once the tightest clip hits the minimum size', () {
      // clip a's narrower edge (80) is the tightest in the group; clip b is
      // comfortably larger on both edges.
      final a = _clip(id: 'a', x: 0, y: 0, width: 100, height: 80);
      final b = _clip(id: 'b', x: 100, y: 0, width: 90, height: 200);
      final startRect = ClipGeometry.boardBoundingBox([a, b]);
      expect(startRect, const Rect.fromLTWH(0, 0, 190, 200));

      // Naive (unclamped) scale would be 0.1 - far below what clip a's
      // 80px edge can tolerate (minClipSize is 40).
      final results = ClipGeometry.scaleGroup(
        startClips: {'a': a, 'b': b},
        startGroupRect: startRect,
        corner: HandleKind.resizeBR,
        pointerBoard: const Offset(19, 20),
      );

      final ra = results['a']!;
      final rb = results['b']!;
      // Clamped scale is 40/80 = 0.5, not the naive 0.1.
      expect(ra.width, closeTo(50, 1e-9));
      expect(ra.height, closeTo(40, 1e-9));
      expect(ra.height, closeTo(ClipGeometry.minClipSize, 1e-9));
      // clip b scaled by that exact same 0.5 factor, not clamped on its own.
      expect(rb.x, closeTo(50, 1e-9));
      expect(rb.y, closeTo(0, 1e-9));
      expect(rb.width, closeTo(45, 1e-9));
      expect(rb.height, closeTo(100, 1e-9));
    });

    test('a degenerate drag (pointer on the anchor) never produces zero/negative size', () {
      final a = _clip(id: 'a', x: 0, y: 0, width: 100, height: 60);
      final startRect = ClipGeometry.boardBoundingBox([a]);

      final result = ClipGeometry.scaleGroup(
        startClips: {'a': a},
        startGroupRect: startRect,
        corner: HandleKind.resizeBR,
        pointerBoard: const Offset(0, 0), // exactly on the TL anchor
      )['a']!;

      expect(result.width, greaterThan(0));
      expect(result.height, greaterThan(0));
    });
  });
}
