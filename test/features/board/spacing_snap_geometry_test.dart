import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/geometry/spacing_snap_geometry.dart';

void main() {
  group('SpacingSnapGeometry.snap - continue rhythm', () {
    test('snaps dragged selection to match an established left-chain gap', () {
      // A at x=0..100, B at x=150..250 (established gap 50), dragged C
      // starts at x=400..500 moving to x=296..396 (gap to B would be 46,
      // 4px short of the established 50) - should snap to make the gap
      // exactly 50.
      final result = SpacingSnapGeometry.snap(
        draggedBoundsBeforeDelta: const Rect.fromLTWH(400, 0, 100, 100),
        delta: const Offset(-104, 0),
        others: [
          const Rect.fromLTWH(0, 0, 100, 100),
          const Rect.fromLTWH(150, 0, 100, 100),
        ],
        threshold: 8,
      );
      expect(result.guideX!.distance, closeTo(50, 0.001));
      expect(result.delta.dx, closeTo(-100, 0.001)); // lands C at 300..400
    });

    test('does not snap when the established gap is outside threshold', () {
      // Same as above, but needed adjustment (4px for established 50 vs
      // 10px actual shortfall) exceeds threshold.
      final result = SpacingSnapGeometry.snap(
        draggedBoundsBeforeDelta: const Rect.fromLTWH(400, 0, 100, 100),
        delta: const Offset(-90, 0), // gap to B would be 60, 10px over
        others: [
          const Rect.fromLTWH(0, 0, 100, 100),
          const Rect.fromLTWH(150, 0, 100, 100),
        ],
        threshold: 8,
      );
      expect(result.guideX, isNull);
    });

    test('snaps dragged selection to match an established right-chain gap', () {
      // A at x=0..100, B at x=150..250 (established gap 50). Dragged C
      // approaches from the left, so its *right* neighbor is A and A's own
      // right neighbor is B - continuing the rhythm on C's right side.
      // C starts far away and moves to x=-146..-46 (gap to A's left edge
      // would be 46, 4px short of the established 50).
      final result = SpacingSnapGeometry.snap(
        draggedBoundsBeforeDelta: const Rect.fromLTWH(-600, 0, 100, 100),
        delta: const Offset(454, 0),
        others: [
          const Rect.fromLTWH(0, 0, 100, 100),
          const Rect.fromLTWH(150, 0, 100, 100),
        ],
        threshold: 8,
      );
      expect(result.guideX!.distance, closeTo(50, 0.001));
      // lands C at -150..-50, so gap to A (x=0) is exactly 50
      expect(result.delta.dx, closeTo(450, 0.001));
    });
  });

  group('SpacingSnapGeometry.snap - equal-margin centering', () {
    test('centers a sandwiched selection with no third reference gap', () {
      // Left neighbor at x=0..100, right neighbor at x=300..400 (200px
      // gap between them), dragged 100-wide selection nearly centered
      // (would leave 48/52 split) should snap to an exact 50/50 split.
      final result = SpacingSnapGeometry.snap(
        draggedBoundsBeforeDelta: const Rect.fromLTWH(1000, 0, 100, 100),
        delta: const Offset(-852, 0), // lands at 148..248 (gaps 48 / 52)
        others: [
          const Rect.fromLTWH(0, 0, 100, 100),
          const Rect.fromLTWH(300, 0, 100, 100),
        ],
        threshold: 8,
      );
      expect(result.guideX!.distance, closeTo(50, 0.001));
      expect(result.delta.dx, closeTo(-850, 0.001)); // lands at 150..250
    });

    test(
      'does not centering-snap when the selection does not fit between neighbors',
      () {
        final result = SpacingSnapGeometry.snap(
          draggedBoundsBeforeDelta: const Rect.fromLTWH(1000, 0, 500, 100),
          delta: const Offset(-852, 0),
          others: [
            const Rect.fromLTWH(0, 0, 100, 100),
            const Rect.fromLTWH(300, 0, 100, 100),
          ],
          threshold: 8,
        );
        expect(result.guideX, isNull);
      },
    );
  });

  group('SpacingSnapGeometry.snap - same-row/column filtering', () {
    test(
      'ignores a candidate pair whose perpendicular extent does not overlap',
      () {
        // "Established gap" pair sits far below on Y (no overlap with the
        // dragged selection's Y-range) - must not be treated as a
        // same-row neighbor even though its X-gap would otherwise match.
        final result = SpacingSnapGeometry.snap(
          draggedBoundsBeforeDelta: const Rect.fromLTWH(400, 0, 100, 100),
          delta: const Offset(-104, 0),
          others: [
            const Rect.fromLTWH(0, 500, 100, 100), // Y: 500-600, no overlap
            const Rect.fromLTWH(150, 500, 100, 100), // Y: 500-600, no overlap
          ],
          threshold: 8,
        );
        expect(result.guideX, isNull);
      },
    );

    test('Y-axis spacing uses the perpendicular (X) overlap test', () {
      // Vertical column: A at y=0..100, B at y=150..250 (gap 50), both at
      // x=0..100 (full X overlap with dragged). Dragged C approaches from
      // below, 4px short of continuing the vertical rhythm.
      final result = SpacingSnapGeometry.snap(
        draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 400, 100, 100),
        delta: const Offset(0, -104),
        others: [
          const Rect.fromLTWH(0, 0, 100, 100),
          const Rect.fromLTWH(0, 150, 100, 100),
        ],
        threshold: 8,
      );
      expect(result.guideY!.distance, closeTo(50, 0.001));
      expect(result.delta.dy, closeTo(-100, 0.001));
    });
  });

  group('SpacingSnapGeometry.snapWithEdges - tie-break with edge-snap', () {
    test('edge-snap wins when its required adjustment is smaller', () {
      // A, B establish a gap of 50; dragged's gap to B is 48, needing a
      // 2px adjustment to reach 50. An unrelated off-row rect C (far on Y,
      // so it never becomes a spacing neighbor) has its right edge 1px
      // from dragged's current left edge - a smaller adjustment - so
      // edge-snap wins.
      final result = SpacingSnapGeometry.snapWithEdges(
        draggedBoundsBeforeDelta: const Rect.fromLTWH(400, 0, 100, 100),
        delta: const Offset(-102, 0), // lands at x=298..398; gap to B is 48
        others: [
          const Rect.fromLTWH(0, 0, 100, 100),
          const Rect.fromLTWH(150, 0, 100, 100), // establishes gap 50
          const Rect.fromLTWH(247, 500, 50, 1), // right edge at x=297, off-row
        ],
        edgeThreshold: 8,
        spacingThreshold: 8,
      );
      expect(result.guideX, closeTo(297, 0.001));
      expect(result.spacingGuideX, isNull);
    });

    test('spacing-snap wins when its required adjustment is smaller', () {
      // Dragged's gap to B is 49, needing only a 1px adjustment to reach
      // the established 50. An unrelated off-row rect C's right edge is
      // 6px from dragged's current left edge - a larger adjustment - so
      // spacing-snap wins.
      final result = SpacingSnapGeometry.snapWithEdges(
        draggedBoundsBeforeDelta: const Rect.fromLTWH(400, 0, 100, 100),
        delta: const Offset(-101, 0), // lands at x=299..399; gap to B is 49
        others: [
          const Rect.fromLTWH(0, 0, 100, 100),
          const Rect.fromLTWH(150, 0, 100, 100), // establishes gap 50
          const Rect.fromLTWH(243, 500, 50, 1), // right edge at x=293, off-row
        ],
        edgeThreshold: 8,
        spacingThreshold: 8,
      );
      expect(result.spacingGuideX!.distance, closeTo(50, 0.001));
      expect(result.guideX, isNull);
      expect(result.delta.dx, closeTo(-100, 0.001));
    });

    test('falls back to pure edge behavior when there is no spacing match', () {
      final result = SpacingSnapGeometry.snapWithEdges(
        draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
        delta: const Offset(96, 0),
        others: [const Rect.fromLTWH(200, 50, 100, 100)],
        edgeThreshold: 8,
        spacingThreshold: 8,
      );
      expect(result.delta.dx, closeTo(100, 0.001));
      expect(result.guideX, closeTo(200, 0.001));
      expect(result.spacingGuideX, isNull);
    });

    test('empty others pool: no edge match, no spacing match', () {
      final result = SpacingSnapGeometry.snapWithEdges(
        draggedBoundsBeforeDelta: const Rect.fromLTWH(0, 0, 100, 100),
        delta: const Offset(5, 5),
        others: const [],
        edgeThreshold: 8,
        spacingThreshold: 8,
      );
      expect(result.delta, const Offset(5, 5));
      expect(result.guideX, isNull);
      expect(result.guideY, isNull);
      expect(result.spacingGuideX, isNull);
      expect(result.spacingGuideY, isNull);
    });
  });
}
