import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/geometry/frame_geometry.dart';
import 'package:hb_clips/features/board/geometry/selection_geometry.dart'
    show HandleKind;

FrameRow _frame({
  String id = 'frame-1',
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  final now = DateTime(2026);
  return FrameRow(
    id: id,
    boardId: 'board',
    name: 'Frame',
    x: x,
    y: y,
    width: width,
    height: height,
    backgroundColorHex: null,
    createdAt: now,
    updatedAt: now,
  );
}

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
  group('pointInFrameOrTitleBand', () {
    test('a point inside the frame body counts', () {
      final frame = _frame(x: 0, y: 0, width: 200, height: 100);
      expect(
        FrameGeometry.pointInFrameOrTitleBand(const Offset(50, 50), frame),
        isTrue,
      );
    });

    test('a point in the title band above the frame counts', () {
      final frame = _frame(x: 0, y: 100, width: 200, height: 100);
      // 10px above the frame's top edge - within the 32px band.
      expect(
        FrameGeometry.pointInFrameOrTitleBand(const Offset(50, 90), frame),
        isTrue,
      );
    });

    test('a point above the band (too far up) does not count', () {
      final frame = _frame(x: 0, y: 100, width: 200, height: 100);
      expect(
        FrameGeometry.pointInFrameOrTitleBand(const Offset(50, 50), frame),
        isFalse,
      );
    });

    test(
      'a point beside the frame (same y as body, outside x range) does not count',
      () {
        final frame = _frame(x: 0, y: 0, width: 200, height: 100);
        expect(
          FrameGeometry.pointInFrameOrTitleBand(const Offset(300, 50), frame),
          isFalse,
        );
      },
    );

    test(
      'pointInFrame itself stays band-unaware (used for drop containment)',
      () {
        final frame = _frame(x: 0, y: 100, width: 200, height: 100);
        expect(
          FrameGeometry.pointInFrame(const Offset(50, 90), frame),
          isFalse,
        );
      },
    );
  });

  group('pointInTitleBand', () {
    test('true only for the band, not the body', () {
      final frame = _frame(x: 0, y: 100, width: 200, height: 100);
      expect(
        FrameGeometry.pointInTitleBand(const Offset(50, 90), frame),
        isTrue,
      );
      expect(
        FrameGeometry.pointInTitleBand(const Offset(50, 150), frame),
        isFalse,
      );
    });
  });

  group('marqueeIntersects', () {
    test('overlapping rects intersect', () {
      final frame = _frame(x: 0, y: 0, width: 100, height: 100);
      expect(
        FrameGeometry.marqueeIntersects(
          const Rect.fromLTWH(50, 50, 100, 100),
          frame,
        ),
        isTrue,
      );
    });

    test('a marquee fully outside the frame does not intersect', () {
      final frame = _frame(x: 0, y: 0, width: 100, height: 100);
      expect(
        FrameGeometry.marqueeIntersects(
          const Rect.fromLTWH(200, 200, 50, 50),
          frame,
        ),
        isFalse,
      );
    });

    test('a marquee fully containing the frame intersects', () {
      final frame = _frame(x: 10, y: 10, width: 20, height: 20);
      expect(
        FrameGeometry.marqueeIntersects(
          const Rect.fromLTWH(0, 0, 100, 100),
          frame,
        ),
        isTrue,
      );
    });
  });

  group('scaleFrameGroup', () {
    test('scales a 2-frame group from the bounding box corner', () {
      final frameA = _frame(id: 'a', x: 0, y: 0, width: 100, height: 100);
      final frameB = _frame(id: 'b', x: 200, y: 0, width: 100, height: 100);
      final groupRect = const Rect.fromLTWH(0, 0, 300, 100);

      final result = FrameGeometry.scaleFrameGroup(
        startFrameRects: {
          'a': FrameGeometry.boardRect(frameA),
          'b': FrameGeometry.boardRect(frameB),
        },
        startChildRects: const {},
        startGroupRect: groupRect,
        corner: HandleKind.resizeBR,
        pointerBoard: const Offset(600, 200),
      );

      expect(result.frames['a'], const Rect.fromLTWH(0, 0, 200, 200));
      expect(result.frames['b'], const Rect.fromLTWH(400, 0, 200, 200));
    });

    test('a child clip inside a scaled frame keeps its relative offset', () {
      final frameA = _frame(id: 'a', x: 0, y: 0, width: 100, height: 100);
      final frameB = _frame(id: 'b', x: 200, y: 0, width: 100, height: 100);
      final groupRect = const Rect.fromLTWH(0, 0, 300, 100);

      final result = FrameGeometry.scaleFrameGroup(
        startFrameRects: {
          'a': FrameGeometry.boardRect(frameA),
          'b': FrameGeometry.boardRect(frameB),
        },
        startChildRects: const {'child': Rect.fromLTWH(20, 20, 10, 10)},
        startGroupRect: groupRect,
        corner: HandleKind.resizeBR,
        pointerBoard: const Offset(600, 200),
      );

      final newFrameA = result.frames['a']!;
      final newChild = result.children['child']!;
      // Still 20% in from frame A's own left/top edge, same as before.
      expect(
        (newChild.left - newFrameA.left) / newFrameA.width,
        closeTo(0.2, 1e-9),
      );
      expect(
        (newChild.top - newFrameA.top) / newFrameA.height,
        closeTo(0.2, 1e-9),
      );
    });

    test('floors each frame at minFrameSize even on a drastic shrink', () {
      final frameA = _frame(id: 'a', x: 0, y: 0, width: 50, height: 50);
      final frameB = _frame(id: 'b', x: 100, y: 0, width: 50, height: 50);
      final groupRect = const Rect.fromLTWH(0, 0, 150, 50);

      final result = FrameGeometry.scaleFrameGroup(
        startFrameRects: {
          'a': FrameGeometry.boardRect(frameA),
          'b': FrameGeometry.boardRect(frameB),
        },
        startChildRects: const {},
        startGroupRect: groupRect,
        corner: HandleKind.resizeBR,
        pointerBoard: const Offset(15, 5), // a severe attempted shrink
      );

      final newFrameA = result.frames['a']!;
      expect(newFrameA.width, closeTo(FrameGeometry.minFrameSize, 1e-9));
      expect(newFrameA.height, closeTo(FrameGeometry.minFrameSize, 1e-9));
    });
  });

  group('nextAvailableFrameName', () {
    test('no frames yet -> "Frame 1"', () {
      expect(FrameGeometry.nextAvailableFrameName(const []), 'Frame 1');
    });

    test('picks the next number after the highest used', () {
      final frames = [
        _frame(x: 0, y: 0, width: 10, height: 10).copyWith(name: 'Frame 1'),
        _frame(x: 0, y: 0, width: 10, height: 10).copyWith(name: 'Frame 2'),
      ];
      expect(FrameGeometry.nextAvailableFrameName(frames), 'Frame 3');
    });

    test('reuses a gap left by a deleted frame', () {
      final frames = [
        _frame(x: 0, y: 0, width: 10, height: 10).copyWith(name: 'Frame 1'),
        _frame(x: 0, y: 0, width: 10, height: 10).copyWith(name: 'Frame 3'),
      ];
      expect(FrameGeometry.nextAvailableFrameName(frames), 'Frame 2');
    });

    test('ignores names that do not match the "Frame <n>" pattern', () {
      final frames = [
        _frame(x: 0, y: 0, width: 10, height: 10).copyWith(name: 'Whiteboard'),
        _frame(x: 0, y: 0, width: 10, height: 10).copyWith(name: 'Frame A'),
      ];
      expect(FrameGeometry.nextAvailableFrameName(frames), 'Frame 1');
    });
  });

  group('scaleChildren', () {
    test('growing a frame scales children from its fixed top-left anchor', () {
      final startRect = const Rect.fromLTWH(0, 0, 100, 100);
      final child = _clip(id: 'a', x: 20, y: 20, width: 30, height: 30);

      final results = FrameGeometry.scaleChildren(
        startClips: {'a': child},
        startRect: startRect,
        newRect: const Rect.fromLTWH(0, 0, 200, 200), // 2x both axes
      );

      final r = results['a']!;
      expect(r.x, closeTo(40, 1e-9));
      expect(r.y, closeTo(40, 1e-9));
      expect(r.width, closeTo(60, 1e-9));
      expect(r.height, closeTo(60, 1e-9));
    });

    test('shrinking a frame scales children down proportionally, no floor', () {
      final startRect = const Rect.fromLTWH(0, 0, 100, 100);
      final child = _clip(id: 'a', x: 40, y: 40, width: 50, height: 50);

      final results = FrameGeometry.scaleChildren(
        startClips: {'a': child},
        startRect: startRect,
        newRect: const Rect.fromLTWH(
          0,
          0,
          20,
          20,
        ), // 0.2x - well under minClipSize
      );

      final r = results['a']!;
      expect(r.x, closeTo(8, 1e-9));
      expect(r.y, closeTo(8, 1e-9));
      expect(r.width, closeTo(10, 1e-9));
      expect(r.height, closeTo(10, 1e-9));
    });

    test('non-uniform resize scales each axis independently', () {
      final startRect = const Rect.fromLTWH(10, 10, 100, 50);
      final child = _clip(id: 'a', x: 30, y: 20, width: 20, height: 10);

      final results = FrameGeometry.scaleChildren(
        startClips: {'a': child},
        startRect: startRect,
        newRect: const Rect.fromLTWH(10, 10, 200, 100), // 2x width, 2x height
      );

      final r = results['a']!;
      // Anchor is the frame's fixed top-left (10, 10).
      expect(r.x, closeTo(10 + (30 - 10) * 2, 1e-9));
      expect(r.y, closeTo(10 + (20 - 10) * 2, 1e-9));
      expect(r.width, closeTo(40, 1e-9));
      expect(r.height, closeTo(20, 1e-9));
    });

    test('relative spacing between multiple children stays proportional', () {
      final startRect = const Rect.fromLTWH(0, 0, 100, 100);
      final a = _clip(id: 'a', x: 10, y: 10, width: 10, height: 10);
      final b = _clip(id: 'b', x: 50, y: 50, width: 10, height: 10);
      final startDistance = (Offset(b.x, b.y) - Offset(a.x, a.y)).distance;

      final results = FrameGeometry.scaleChildren(
        startClips: {'a': a, 'b': b},
        startRect: startRect,
        newRect: const Rect.fromLTWH(0, 0, 300, 300), // 3x
      );

      final ra = results['a']!;
      final rb = results['b']!;
      final endDistance = (Offset(rb.x, rb.y) - Offset(ra.x, ra.y)).distance;
      expect(endDistance, closeTo(startDistance * 3, 1e-9));
    });

    test('a frame with no children returns an empty map', () {
      final results = FrameGeometry.scaleChildren(
        startClips: const {},
        startRect: const Rect.fromLTWH(0, 0, 100, 100),
        newRect: const Rect.fromLTWH(0, 0, 50, 50),
      );
      expect(results, isEmpty);
    });
  });
}
