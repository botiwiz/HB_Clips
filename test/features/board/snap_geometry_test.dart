import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/geometry/snap_geometry.dart';

void main() {
  test('snaps right edge to a nearby other rect\'s left edge', () {
    // Dragged rect starts at x=0..100, moves 96px right (to 96..196), which
    // puts its right edge 4px from the other rect's left edge at x=200.
    final result = SnapGeometry.snapDelta(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(96, 0),
      others: [const Rect.fromLTWH(200, 0, 100, 100)],
      threshold: 8,
    );

    expect(result.dx, closeTo(100, 0.001));
    expect(result.dy, 0);
  });

  test('does not snap when the nearest edge is outside the threshold', () {
    final result = SnapGeometry.snapDelta(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(80, 0),
      others: [const Rect.fromLTWH(200, 0, 100, 100)],
      threshold: 8,
    );

    expect(result.dx, closeTo(80, 0.001));
  });

  test('snaps independently on each axis', () {
    // Right edge nearly aligned with other's left edge (snaps on X); top
    // edge nearly aligned with other's bottom edge (snaps on Y).
    final result = SnapGeometry.snapDelta(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(96, 46),
      others: [const Rect.fromLTWH(200, -50, 100, 100)],
      threshold: 8,
    );

    expect(result.dx, closeTo(100, 0.001));
    expect(result.dy, closeTo(50, 0.001));
  });

  test('left edge can snap to another rect\'s right edge', () {
    final result = SnapGeometry.snapDelta(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(300, 0, 100, 100),
      delta: const Offset(-196, 0),
      others: [const Rect.fromLTWH(0, 0, 100, 100)],
      threshold: 8,
    );

    // Other's right edge is at x=100; dragged left edge lands at 104
    // without snapping, 4px away - should pull in to exactly 100.
    expect(result.dx, closeTo(-200, 0.001));
  });

  test('picks the single closest candidate among several on the same axis', () {
    final result = SnapGeometry.snapDelta(
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
    expect(result.dx, closeTo(95, 0.001));
  });

  test('bottom edge can snap to another rect\'s top edge', () {
    final result = SnapGeometry.snapDelta(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(0, 96),
      others: [const Rect.fromLTWH(0, 200, 100, 100)],
      threshold: 8,
    );

    expect(result.dy, closeTo(100, 0.001));
  });

  test('no candidates within threshold on either axis leaves delta unchanged', () {
    final result = SnapGeometry.snapDelta(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(50, 30),
      others: [const Rect.fromLTWH(500, 500, 100, 100)],
      threshold: 8,
    );

    expect(result.dx, closeTo(50, 0.001));
    expect(result.dy, closeTo(30, 0.001));
  });

  test('empty others list leaves delta unchanged', () {
    final result = SnapGeometry.snapDelta(
      draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
      delta: const Offset(12, -7),
      others: const [],
      threshold: 8,
    );

    expect(result, const Offset(12, -7));
  });
}
