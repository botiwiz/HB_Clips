import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/geometry/snap_geometry.dart';

void main() {
  test('snaps right edge to a nearby other rect\'s left edge', () {
    // Dragged rect starts at x=0..100, moves 96px right (to 96..196), which
    // puts its right edge 4px from the other rect's left edge at x=200.
    // The other rect is offset on Y too, so nothing coincidentally aligns
    // on that axis.
    final result = SnapGeometry.snap(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(96, 0),
      others: [const Rect.fromLTWH(200, 50, 100, 100)],
      threshold: 8,
    );

    expect(result.delta.dx, closeTo(100, 0.001));
    expect(result.delta.dy, 0);
    expect(result.guideX, closeTo(200, 0.001));
    expect(result.guideY, isNull);
  });

  test('does not snap when the nearest edge is outside the threshold', () {
    final result = SnapGeometry.snap(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(80, 0),
      others: [const Rect.fromLTWH(200, 0, 100, 100)],
      threshold: 8,
    );

    expect(result.delta.dx, closeTo(80, 0.001));
    expect(result.guideX, isNull);
  });

  test('snaps independently on each axis', () {
    // Right edge nearly aligned with other's left edge (snaps on X); top
    // edge nearly aligned with other's bottom edge (snaps on Y).
    final result = SnapGeometry.snap(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(96, 46),
      others: [const Rect.fromLTWH(200, -50, 100, 100)],
      threshold: 8,
    );

    expect(result.delta.dx, closeTo(100, 0.001));
    expect(result.delta.dy, closeTo(50, 0.001));
    expect(result.guideX, closeTo(200, 0.001));
    expect(result.guideY, closeTo(50, 0.001));
  });

  test('left edge can snap to another rect\'s right edge', () {
    final result = SnapGeometry.snap(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(300, 0, 100, 100),
      delta: const Offset(-196, 0),
      others: [const Rect.fromLTWH(0, 0, 100, 100)],
      threshold: 8,
    );

    // Other's right edge is at x=100; dragged left edge lands at 104
    // without snapping, 4px away - should pull in to exactly 100.
    expect(result.delta.dx, closeTo(-200, 0.001));
    expect(result.guideX, closeTo(100, 0.001));
  });

  test('picks the single closest candidate among several on the same axis', () {
    final result = SnapGeometry.snap(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(94, 0),
      others: [
        // Right edge at 94 -> distance 6 from this one's left edge (200).
        const Rect.fromLTWH(200, 0, 100, 100),
        // Right edge at 94 -> distance 1 from this one's left edge (195).
        const Rect.fromLTWH(195, 0, 100, 100),
      ],
      threshold: 8,
    );

    // Snaps to the closer candidate (195), not the farther one (200).
    expect(result.delta.dx, closeTo(95, 0.001));
    expect(result.guideX, closeTo(195, 0.001));
  });

  test('bottom edge can snap to another rect\'s top edge', () {
    final result = SnapGeometry.snap(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(0, 96),
      others: [const Rect.fromLTWH(0, 200, 100, 100)],
      threshold: 8,
    );

    expect(result.delta.dy, closeTo(100, 0.001));
    expect(result.guideY, closeTo(200, 0.001));
  });

  test('no candidates within threshold on either axis leaves delta unchanged', () {
    final result = SnapGeometry.snap(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(50, 30),
      others: [const Rect.fromLTWH(500, 500, 100, 100)],
      threshold: 8,
    );

    expect(result.delta.dx, closeTo(50, 0.001));
    expect(result.delta.dy, closeTo(30, 0.001));
    expect(result.guideX, isNull);
    expect(result.guideY, isNull);
  });

  test('empty others list leaves delta unchanged with no guides', () {
    final result = SnapGeometry.snap(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(12, -7),
      others: const [],
      threshold: 8,
    );

    expect(result.delta, const Offset(12, -7));
    expect(result.guideX, isNull);
    expect(result.guideY, isNull);
  });

  group('snapPoint (resize/scale free corner)', () {
    test('snaps the point\'s x to a nearby edge', () {
      final result = SnapGeometry.snapPoint(
        point: const Offset(196, 300),
        others: [const Rect.fromLTWH(200, 0, 100, 100)],
        threshold: 8,
      );

      expect(result.point.dx, closeTo(200, 0.001));
      expect(result.point.dy, 300);
      expect(result.guideX, closeTo(200, 0.001));
      expect(result.guideY, isNull);
    });

    test('snaps the point\'s y to a nearby edge', () {
      final result = SnapGeometry.snapPoint(
        point: const Offset(300, 96),
        others: [const Rect.fromLTWH(0, 100, 100, 100)],
        threshold: 8,
      );

      expect(result.point.dy, closeTo(100, 0.001));
      expect(result.guideY, closeTo(100, 0.001));
      expect(result.guideX, isNull);
    });

    test('snaps both axes independently at once', () {
      final result = SnapGeometry.snapPoint(
        point: const Offset(196, 104),
        others: [const Rect.fromLTWH(200, 100, 50, 50)],
        threshold: 8,
      );

      expect(result.point, const Offset(200, 100));
      expect(result.guideX, closeTo(200, 0.001));
      expect(result.guideY, closeTo(100, 0.001));
    });

    test('does not snap when outside the threshold', () {
      final result = SnapGeometry.snapPoint(
        point: const Offset(180, 300),
        others: [const Rect.fromLTWH(200, 0, 100, 100)],
        threshold: 8,
      );

      expect(result.point, const Offset(180, 300));
      expect(result.guideX, isNull);
    });

    test('picks the closest of several candidates', () {
      final result = SnapGeometry.snapPoint(
        point: const Offset(196, 300),
        others: [
          const Rect.fromLTWH(203, 500, 10, 10), // distance 7
          const Rect.fromLTWH(197, 500, 10, 10), // distance 1
        ],
        threshold: 8,
      );

      expect(result.point.dx, closeTo(197, 0.001));
      expect(result.guideX, closeTo(197, 0.001));
    });

    test('empty others leaves the point unchanged with no guides', () {
      final result = SnapGeometry.snapPoint(
        point: const Offset(12, -7),
        others: const [],
        threshold: 8,
      );

      expect(result.point, const Offset(12, -7));
      expect(result.guideX, isNull);
      expect(result.guideY, isNull);
    });
  });
}
