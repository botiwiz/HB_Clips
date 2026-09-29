import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/geometry/frame_geometry.dart';

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
        newRect: const Rect.fromLTWH(0, 0, 20, 20), // 0.2x - well under minClipSize
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
      final startDistance =
          (Offset(b.x, b.y) - Offset(a.x, a.y)).distance;

      final results = FrameGeometry.scaleChildren(
        startClips: {'a': a, 'b': b},
        startRect: startRect,
        newRect: const Rect.fromLTWH(0, 0, 300, 300), // 3x
      );

      final ra = results['a']!;
      final rb = results['b']!;
      final endDistance =
          (Offset(rb.x, rb.y) - Offset(ra.x, ra.y)).distance;
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
