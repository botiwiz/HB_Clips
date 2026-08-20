import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/controllers/board_controller.dart';
import 'package:hb_clips/features/board/geometry/selection_geometry.dart';

BoardClip _clip({
  String id = 'a',
  double x = 0,
  double y = 0,
  double width = 100,
  double height = 60,
  double rotation = 0,
}) {
  final now = DateTime(2026);
  return BoardClip(
    id: id,
    boardId: 'board',
    type: ClipType.text,
    x: x,
    y: y,
    width: width,
    height: height,
    rotation: rotation,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('rotatePoint', () {
    test('90 degrees rotates (1,0) around origin to (0,1)', () {
      final result = ClipGeometry.rotatePoint(
        const Offset(1, 0),
        Offset.zero,
        math.pi / 2,
      );
      expect(result.dx, closeTo(0, 1e-9));
      expect(result.dy, closeTo(1, 1e-9));
    });

    test('180 degrees rotates (1,0) around origin to (-1,0)', () {
      final result = ClipGeometry.rotatePoint(
        const Offset(1, 0),
        Offset.zero,
        math.pi,
      );
      expect(result.dx, closeTo(-1, 1e-9));
      expect(result.dy, closeTo(0, 1e-9));
    });

    test('zero rotation is a no-op', () {
      const point = Offset(3, 4);
      final result = ClipGeometry.rotatePoint(point, const Offset(1, 1), 0);
      expect(result, point);
    });
  });

  group('pointInClip', () {
    test('unrotated clip: point inside/outside bounds', () {
      final clip = _clip(x: 10, y: 10, width: 100, height: 50);
      expect(ClipGeometry.pointInClip(const Offset(50, 30), clip), isTrue);
      expect(ClipGeometry.pointInClip(const Offset(200, 30), clip), isFalse);
    });

    test('rotated 90 degrees: a point along the original width axis moves', () {
      // A wide, short clip centered at (50, 30), rotated 90 degrees becomes
      // tall and narrow visually - a point far to the right of center
      // (inside the unrotated rect) should now be OUTSIDE the rotated clip,
      // while a point above center (outside the unrotated rect) should now
      // be INSIDE it.
      final clip = _clip(x: 0, y: 20, width: 100, height: 20, rotation: math.pi / 2);
      // Center is (50, 30). Unrotated rect spans x:[0,100], y:[20,40].
      expect(ClipGeometry.pointInClip(const Offset(90, 30), clip), isFalse);
      expect(ClipGeometry.pointInClip(const Offset(50, 5), clip), isTrue);
    });
  });

  group('marqueeIntersects', () {
    test('overlapping rect intersects regardless of drag direction', () {
      final clip = _clip(x: 50, y: 50, width: 20, height: 20);
      final topLeftToBottomRight = Rect.fromPoints(
        const Offset(40, 40),
        const Offset(80, 80),
      );
      final bottomRightToTopLeft = Rect.fromPoints(
        const Offset(80, 80),
        const Offset(40, 40),
      );
      expect(ClipGeometry.marqueeIntersects(topLeftToBottomRight, clip), isTrue);
      expect(ClipGeometry.marqueeIntersects(bottomRightToTopLeft, clip), isTrue);
    });

    test('non-overlapping rect does not intersect', () {
      final clip = _clip(x: 50, y: 50, width: 20, height: 20);
      final farAway = Rect.fromLTWH(500, 500, 10, 10);
      expect(ClipGeometry.marqueeIntersects(farAway, clip), isFalse);
    });
  });

  group('hitTestHandle', () {
    const view = BoardViewState(panOffset: Offset.zero, scale: 1);

    test('hits each corner of an unrotated clip', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      expect(
        ClipGeometry.hitTestHandle(clip, view, const Offset(0, 0)),
        HandleKind.resizeTL,
      );
      expect(
        ClipGeometry.hitTestHandle(clip, view, const Offset(100, 0)),
        HandleKind.resizeTR,
      );
      expect(
        ClipGeometry.hitTestHandle(clip, view, const Offset(100, 60)),
        HandleKind.resizeBR,
      );
      expect(
        ClipGeometry.hitTestHandle(clip, view, const Offset(0, 60)),
        HandleKind.resizeBL,
      );
    });

    test('hits the rotate handle above the top edge', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      final rotateScreen = ClipGeometry.rotateHandleScreenPosition(clip, view);
      expect(
        ClipGeometry.hitTestHandle(clip, view, rotateScreen),
        HandleKind.rotate,
      );
    });

    test('a point far from every handle misses', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      expect(
        ClipGeometry.hitTestHandle(clip, view, const Offset(50, 30)),
        isNull,
      );
    });

    test('corner hit-testing accounts for rotation', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60, rotation: math.pi / 2);
      final corners = ClipGeometry.handleScreenPositions(clip, view);
      expect(
        ClipGeometry.hitTestHandle(clip, view, corners[HandleKind.resizeTL]!),
        HandleKind.resizeTL,
      );
      // The original (unrotated) TL screen position (0,0) should no longer
      // register as a hit once the clip is rotated 90 degrees.
      expect(
        ClipGeometry.hitTestHandle(clip, view, const Offset(0, 0)),
        isNot(HandleKind.resizeTL),
      );
    });
  });

  group('resize', () {
    test('dragging TL keeps BR anchored and clamps to the minimum size', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      final result = ClipGeometry.resize(
        startClip: clip,
        corner: HandleKind.resizeTL,
        pointerBoard: const Offset(90, 55), // dragged almost onto the anchor
      );
      // Anchor (BR) is fixed at (100, 60).
      expect(result.x + result.width, closeTo(100, 1e-9));
      expect(result.y + result.height, closeTo(60, 1e-9));
      expect(result.width, greaterThanOrEqualTo(ClipGeometry.minClipSize));
      expect(result.height, greaterThanOrEqualTo(ClipGeometry.minClipSize));
    });

    test('dragging BR outward grows the rect from the fixed TL anchor', () {
      final clip = _clip(x: 10, y: 10, width: 100, height: 60);
      final result = ClipGeometry.resize(
        startClip: clip,
        corner: HandleKind.resizeBR,
        pointerBoard: const Offset(210, 110),
      );
      expect(result.x, closeTo(10, 1e-9));
      expect(result.y, closeTo(10, 1e-9));
      expect(result.width, closeTo(200, 1e-9));
      expect(result.height, closeTo(100, 1e-9));
    });
  });

  group('rotate', () {
    test('quarter turn of the pointer rotates the clip by 90 degrees', () {
      const center = Offset(50, 50);
      final rotation = ClipGeometry.rotate(
        rotation0: 0,
        center: center,
        startPointerBoard: const Offset(100, 50), // due east of center
        currentPointerBoard: const Offset(50, 100), // due south of center
      );
      expect(rotation, closeTo(math.pi / 2, 1e-9));
    });

    test('full loop back to the start returns to the original rotation', () {
      const center = Offset(0, 0);
      const start = Offset(10, 0);
      final rotation = ClipGeometry.rotate(
        rotation0: 0.4,
        center: center,
        startPointerBoard: start,
        currentPointerBoard: start,
      );
      expect(rotation, closeTo(0.4, 1e-9));
    });
  });

  group('applyGroupDelta', () {
    test('applies the same delta to every clip start position', () {
      final result = ClipGeometry.applyGroupDelta(
        {'a': const Offset(0, 0), 'b': const Offset(10, 20)},
        const Offset(5, -5),
      );
      expect(result['a'], const Offset(5, -5));
      expect(result['b'], const Offset(15, 15));
    });
  });
}
