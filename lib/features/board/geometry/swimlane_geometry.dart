import 'package:flutter/rendering.dart';

import '../../../data/local/database.dart' show SwimlaneRow, FrameRow;

/// Pure geometry for swimlane containment/rendering - the horizontal-band
/// counterpart to `FrameGeometry`'s column containment. A swimlane has no
/// stored x/width (see `Swimlanes` table doc comment), so every check
/// here takes the caller-computed column-span rect as an explicit param
/// rather than reading it off the row itself.
class SwimlaneGeometry {
  SwimlaneGeometry._();

  /// Bounding union of [columns] (one kanban board's tagged Frames) in
  /// board space - the one place this "derive, don't cache" rect is
  /// computed, shared by [pointInSwimlane] and the swimlane-divider
  /// renderer. Null if [columns] is empty (a kanban board whose every
  /// column Frame was deleted - a swimlane with no columns left renders
  /// nothing and accepts no clips).
  static Rect? columnSpanBoardRect(List<FrameRow> columns) {
    if (columns.isEmpty) return null;
    var rect = Rect.fromLTWH(
      columns.first.x,
      columns.first.y,
      columns.first.width,
      columns.first.height,
    );
    for (final f in columns.skip(1)) {
      rect = rect.expandToInclude(Rect.fromLTWH(f.x, f.y, f.width, f.height));
    }
    return rect;
  }

  /// Whether [boardPoint] falls within [swimlane]'s y-range AND within
  /// [columnSpan]'s x-range - the intersection is deliberate: a point can
  /// be "in" a swimlane without being in any column, but never outside
  /// its own board's horizontal footprint (a bare y-range test alone
  /// would false-positive across unrelated kanban boards sharing a
  /// y-band on an infinite canvas with multiple boards at different
  /// x-positions).
  static bool pointInSwimlane(
    Offset boardPoint,
    SwimlaneRow swimlane,
    Rect columnSpan,
  ) {
    final inYRange =
        boardPoint.dy >= swimlane.y &&
        boardPoint.dy < swimlane.y + swimlane.height;
    final inXRange =
        boardPoint.dx >= columnSpan.left && boardPoint.dx < columnSpan.right;
    return inYRange && inXRange;
  }
}
