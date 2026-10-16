import 'package:flutter/rendering.dart';

import 'snap_geometry.dart';

/// One matched spacing-snap result on a single axis - the richer
/// counterpart to [SnapResult]'s single `guideX`/`guideY` double, carrying
/// everything `SnapGuidesOverlay` needs to draw Miro-style tick-mark
/// brackets plus a numeric label, not just a line position.
class SpacingGuide {
  /// Axis.horizontal: gap measured along X between left/right neighbors in
  /// the same row. Axis.vertical: gap measured along Y between top/bottom
  /// neighbors in the same column.
  final Axis axis;

  /// The matched gap distance in board units, shown in the label.
  final double distance;

  /// Board-space rects of exactly the 2 gaps now equal to [distance]: for
  /// "continue rhythm", [dragged-to-neighbor gap, the established
  /// reference gap between the neighbor and ITS neighbor]; for
  /// "equal-margin centering", [dragged-to-left-neighbor gap,
  /// dragged-to-right-neighbor gap]. Each rect spans the facing elements'
  /// shared perpendicular-axis overlap - `SnapGuidesOverlay` brackets each
  /// one with tick marks and centers the numeric label over `gapRects[0]`.
  final List<Rect> gapRects;

  const SpacingGuide({
    required this.axis,
    required this.distance,
    required this.gapRects,
  });

  @override
  bool operator ==(Object other) =>
      other is SpacingGuide &&
      other.axis == axis &&
      other.distance == distance &&
      other.gapRects.length == gapRects.length &&
      other.gapRects[0] == gapRects[0] &&
      other.gapRects[1] == gapRects[1];

  @override
  int get hashCode => Object.hash(axis, distance, gapRects[0], gapRects[1]);
}

/// Result of [SpacingSnapGeometry.snap]: the adjusted drag delta, plus
/// whichever [SpacingGuide] matched on each axis - null means nothing
/// matched on that axis.
class SpacingSnapResult {
  final Offset delta;
  final SpacingGuide? guideX;
  final SpacingGuide? guideY;

  const SpacingSnapResult({required this.delta, this.guideX, this.guideY});
}

/// Result of [SpacingSnapGeometry.snapWithEdges]: the adjusted delta, plus
/// whichever guide type (plain edge-alignment or spacing) won on each
/// axis - at most one of `{guideX, spacingGuideX}` is non-null (same for
/// Y), since the two guide types never render simultaneously on one axis.
class CombinedSnapResult {
  final Offset delta;
  final double? guideX;
  final double? guideY;
  final SpacingGuide? spacingGuideX;
  final SpacingGuide? spacingGuideY;

  const CombinedSnapResult({
    required this.delta,
    this.guideX,
    this.guideY,
    this.spacingGuideX,
    this.spacingGuideY,
  });
}

/// Pure geometry for Miro/Figma-style "equal spacing" smart guides - a
/// sibling of [SnapGeometry] (which only does nearest-edge alignment) that
/// additionally detects two kinds of spacing match while dragging a
/// selection among same-row/column neighbors:
///
///  - "Continue rhythm": the dragged selection's gap to its nearest
///    neighbor matches a gap already established between that neighbor and
///    ITS own nearest neighbor further along the axis.
///  - "Equal-margin centering": the dragged selection sits between a left
///    and a right (or top and bottom) neighbor with no third reference gap
///    needed - snaps so both gaps become exactly equal.
///
/// [SnapGeometry.snap]/[SnapGeometry.snapPoint] are never modified by this
/// class - [snapWithEdges] calls the existing function as a black box and
/// composes its result with this class's own, so every existing edge-snap
/// test and call site keeps behaving identically. No widget imports beyond
/// `package:flutter/rendering.dart` (for `Rect`/`Offset`/`Axis`) - unit
/// tested directly in `test/features/board/spacing_snap_geometry_test.dart`.
class SpacingSnapGeometry {
  SpacingSnapGeometry._();

  /// Whether [a] and [b] could be considered part of the same row
  /// (`axis == Axis.horizontal`, i.e. X-axis spacing - their Y-ranges
  /// overlap) or the same column (`axis == Axis.vertical` - their X-ranges
  /// overlap). The standard Figma/Miro rule for what counts as a spacing
  /// neighbor: an element floating above/below (or left/right of) the
  /// dragged selection with no shared extent on the perpendicular axis is
  /// never a spacing neighbor, no matter how close its near edge is along
  /// the primary axis.
  static bool _perpendicularOverlap(Rect a, Rect b, Axis axis) {
    if (axis == Axis.horizontal) {
      return a.top < b.bottom && b.top < a.bottom;
    }
    return a.left < b.right && b.left < a.right;
  }

  /// [anchor]'s immediate same-row/column neighbor on one side
  /// (`before: true` = left/top of [anchor]), searched fresh against the
  /// full [others] pool and filtered for perpendicular overlap with
  /// [anchor] itself - needed so "the neighbor's own neighbor" lookup can
  /// test row/column membership relative to the neighbor, which can have a
  /// different Y/X extent than the original dragged selection. Returns
  /// whichever candidate has the smallest non-negative gap to [anchor]'s
  /// near edge on that side, or null if nothing sits there at all.
  static Rect? _neighborOf(
    Rect anchor,
    List<Rect> others,
    Axis axis, {
    required bool before,
  }) {
    Rect? best;
    var bestGap = double.infinity;
    for (final other in others) {
      if (other == anchor) continue;
      if (!_perpendicularOverlap(anchor, other, axis)) continue;
      final gap = before
          ? (axis == Axis.horizontal
                ? anchor.left - other.right
                : anchor.top - other.bottom)
          : (axis == Axis.horizontal
                ? other.left - anchor.right
                : other.top - anchor.bottom);
      if (gap >= 0 && gap < bestGap) {
        bestGap = gap;
        best = other;
      }
    }
    return best;
  }

  /// Board-space rect of the gap between [a] (nearer the origin on [axis])
  /// and [b], clipped to their shared perpendicular-axis overlap - a thin
  /// strip whose length along [axis] is the gap distance, used by
  /// `SnapGuidesOverlay` to draw the bracket shaft + end-caps and center
  /// the label.
  static Rect _gapRect(Rect a, Rect b, Axis axis) {
    if (axis == Axis.horizontal) {
      final top = a.top > b.top ? a.top : b.top;
      final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;
      return Rect.fromLTRB(a.right, top, b.left, bottom);
    }
    final left = a.left > b.left ? a.left : b.left;
    final right = a.right < b.right ? a.right : b.right;
    return Rect.fromLTRB(left, a.bottom, right, b.top);
  }

  /// Adjusts [delta] so the dragged selection's bounding box - starting
  /// from [draggedBoundsBeforeDelta] and shifted by [delta] - either
  /// continues an established neighbor-to-neighbor gap, or centers evenly
  /// between a left/right (or top/bottom) neighbor pair, independently per
  /// axis, if a match is within [threshold] board units. Each axis's three
  /// candidates (continue-rhythm-left, continue-rhythm-right,
  /// equal-margin-centering) compete for whichever requires the smallest
  /// adjustment, same discipline as [SnapGeometry.snap]'s own internal
  /// candidate competition.
  static SpacingSnapResult snap({
    required Rect draggedBoundsBeforeDelta,
    required Offset delta,
    required List<Rect> others,
    required double threshold,
  }) {
    final dragged = draggedBoundsBeforeDelta.shift(delta);
    final x = _snapAxis(dragged, others, Axis.horizontal, threshold);
    final y = _snapAxis(dragged, others, Axis.vertical, threshold);
    return SpacingSnapResult(
      delta: Offset(
        delta.dx + (x?.adjustment ?? 0),
        delta.dy + (y?.adjustment ?? 0),
      ),
      guideX: x?.guide,
      guideY: y?.guide,
    );
  }

  static ({double adjustment, SpacingGuide guide})? _snapAxis(
    Rect dragged,
    List<Rect> others,
    Axis axis,
    double threshold,
  ) {
    final left = _neighborOf(dragged, others, axis, before: true);
    final right = _neighborOf(dragged, others, axis, before: false);

    double? bestAdjustment;
    SpacingGuide? bestGuide;
    void consider(double adjustment, SpacingGuide guide) {
      if (adjustment.abs() <= threshold &&
          (bestAdjustment == null ||
              adjustment.abs() < bestAdjustment!.abs())) {
        bestAdjustment = adjustment;
        bestGuide = guide;
      }
    }

    Rect shiftNear(double adjustment) => axis == Axis.horizontal
        ? dragged.shift(Offset(adjustment, 0))
        : dragged.shift(Offset(0, adjustment));

    if (left != null) {
      final leftOfLeft = _neighborOf(left, others, axis, before: true);
      if (leftOfLeft != null) {
        final gap = axis == Axis.horizontal
            ? left.left - leftOfLeft.right
            : left.top - leftOfLeft.bottom;
        if (gap > 0) {
          final leftFar = axis == Axis.horizontal ? left.right : left.bottom;
          final targetNear = leftFar + gap;
          final currentNear = axis == Axis.horizontal
              ? dragged.left
              : dragged.top;
          final adjustment = targetNear - currentNear;
          consider(
            adjustment,
            SpacingGuide(
              axis: axis,
              distance: gap,
              gapRects: [
                _gapRect(left, shiftNear(adjustment), axis),
                _gapRect(leftOfLeft, left, axis),
              ],
            ),
          );
        }
      }
    }

    if (right != null) {
      final rightOfRight = _neighborOf(right, others, axis, before: false);
      if (rightOfRight != null) {
        final gap = axis == Axis.horizontal
            ? rightOfRight.left - right.right
            : rightOfRight.top - right.bottom;
        if (gap > 0) {
          final rightNear = axis == Axis.horizontal ? right.left : right.top;
          final targetFar = rightNear - gap;
          final size = axis == Axis.horizontal ? dragged.width : dragged.height;
          final targetNear = targetFar - size;
          final currentNear = axis == Axis.horizontal
              ? dragged.left
              : dragged.top;
          final adjustment = targetNear - currentNear;
          consider(
            adjustment,
            SpacingGuide(
              axis: axis,
              distance: gap,
              gapRects: [
                _gapRect(shiftNear(adjustment), right, axis),
                _gapRect(right, rightOfRight, axis),
              ],
            ),
          );
        }
      }
    }

    if (left != null && right != null) {
      final available = axis == Axis.horizontal
          ? right.left - left.right
          : right.top - left.bottom;
      final size = axis == Axis.horizontal ? dragged.width : dragged.height;
      if (available >= size) {
        final gapEach = (available - size) / 2;
        final leftFar = axis == Axis.horizontal ? left.right : left.bottom;
        final targetNear = leftFar + gapEach;
        final currentNear = axis == Axis.horizontal
            ? dragged.left
            : dragged.top;
        final adjustment = targetNear - currentNear;
        final shifted = shiftNear(adjustment);
        consider(
          adjustment,
          SpacingGuide(
            axis: axis,
            distance: gapEach,
            gapRects: [
              _gapRect(left, shifted, axis),
              _gapRect(shifted, right, axis),
            ],
          ),
        );
      }
    }

    if (bestGuide == null) return null;
    return (adjustment: bestAdjustment!, guide: bestGuide!);
  }

  /// Combines plain edge-alignment snapping ([SnapGeometry.snap], called
  /// unmodified) with this class's own spacing-snap detection against the
  /// same [others] candidate pool. Per axis, independently, whichever of
  /// {edge-match, spacing-match} requires the smaller absolute adjustment
  /// to the raw drag delta wins - i.e. whichever snap target the pointer
  /// is actually already closer to. Ties favor edge-snap (the simpler,
  /// pre-existing concept), keeping behavior backward-compatible in the
  /// degenerate case where both land on the exact same point. At most one
  /// of `{guideX, spacingGuideX}` is ever non-null (same for Y).
  static CombinedSnapResult snapWithEdges({
    required Rect draggedBoundsBeforeDelta,
    required Offset delta,
    required List<Rect> others,
    required double edgeThreshold,
    required double spacingThreshold,
  }) {
    final edge = SnapGeometry.snap(
      draggedBoundsBeforeDelta: draggedBoundsBeforeDelta,
      delta: delta,
      others: others,
      threshold: edgeThreshold,
    );
    final spacing = snap(
      draggedBoundsBeforeDelta: draggedBoundsBeforeDelta,
      delta: delta,
      others: others,
      threshold: spacingThreshold,
    );

    ({double value, double? edgeGuide, SpacingGuide? spacingGuide}) pickAxis(
      double raw,
      double edgeAdjusted,
      double? edgeGuide,
      double spacingAdjusted,
      SpacingGuide? spacingGuide,
    ) {
      if (edgeGuide != null && spacingGuide != null) {
        final edgeMag = (edgeAdjusted - raw).abs();
        final spacingMag = (spacingAdjusted - raw).abs();
        return edgeMag <= spacingMag
            ? (value: edgeAdjusted, edgeGuide: edgeGuide, spacingGuide: null)
            : (
                value: spacingAdjusted,
                edgeGuide: null,
                spacingGuide: spacingGuide,
              );
      }
      if (edgeGuide != null) {
        return (value: edgeAdjusted, edgeGuide: edgeGuide, spacingGuide: null);
      }
      if (spacingGuide != null) {
        return (
          value: spacingAdjusted,
          edgeGuide: null,
          spacingGuide: spacingGuide,
        );
      }
      return (value: raw, edgeGuide: null, spacingGuide: null);
    }

    final x = pickAxis(
      delta.dx,
      edge.delta.dx,
      edge.guideX,
      spacing.delta.dx,
      spacing.guideX,
    );
    final y = pickAxis(
      delta.dy,
      edge.delta.dy,
      edge.guideY,
      spacing.delta.dy,
      spacing.guideY,
    );

    return CombinedSnapResult(
      delta: Offset(x.value, y.value),
      guideX: x.edgeGuide,
      guideY: y.edgeGuide,
      spacingGuideX: x.spacingGuide,
      spacingGuideY: y.spacingGuide,
    );
  }
}
