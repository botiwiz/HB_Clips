import 'package:flutter/rendering.dart';

import '../../../data/models/clip.dart';

/// Board-space (world) layout constants for a kanban card's internal
/// rows - title band, one row per checklist item, an "+ Add item" row,
/// and the link button - shared between `ClipWidget._buildKanbanCard`
/// (drawing) and `board_canvas.dart`'s click interpretation (hit-testing
/// checkbox/add-item/link-button taps), same role `FrameGeometry
/// .titleBandHeight` plays for frame title bands.
class KanbanCardGeometry {
  KanbanCardGeometry._();

  static const double titleBandHeight = 28;
  static const double rowHeight = 24;
  static const double linkButtonSize = 20;
  static const double padding = 8;

  /// Board-space rect of the title band, local to the clip's own
  /// top-left (i.e. relative, not yet offset by the clip's x/y).
  static Rect titleRectLocal(BoardClip clip) => Rect.fromLTWH(
    padding,
    padding,
    clip.width - 2 * padding,
    titleBandHeight,
  );

  /// Board-space rect of checklist row [index] (its full row, including
  /// the checkbox glyph at its left edge), local to the clip's top-left.
  static Rect checklistRowRectLocal(BoardClip clip, int index) =>
      Rect.fromLTWH(
        padding,
        padding + titleBandHeight + index * rowHeight,
        clip.width - 2 * padding,
        rowHeight,
      );

  /// Board-space rect of the trailing "+ Add item" row, local to the
  /// clip's top-left.
  static Rect addItemRowRectLocal(BoardClip clip, int itemCount) =>
      checklistRowRectLocal(clip, itemCount);

  /// Board-space rect of just checklist row [index]'s checkbox glyph
  /// (the leading ~22px of the row - 16px icon + 6px spacing, matching
  /// `ClipWidget._buildKanbanCard`'s `Row`) - narrower than the full row
  /// so a click there toggles `done` while a click on the label text
  /// elsewhere in the row starts editing it instead.
  static Rect checklistCheckboxRectLocal(BoardClip clip, int index) {
    final row = checklistRowRectLocal(clip, index);
    return Rect.fromLTWH(row.left, row.top, 22, row.height);
  }

  /// Board-space rect of the link button, local to the clip's top-left -
  /// pinned to the title band's trailing edge.
  static Rect linkButtonRectLocal(BoardClip clip) => Rect.fromLTWH(
    clip.width - padding - linkButtonSize,
    padding + (titleBandHeight - linkButtonSize) / 2,
    linkButtonSize,
    linkButtonSize,
  );

  /// Any of the above, translated into board-space absolute coordinates
  /// (clip.x/clip.y + the local rect) - what `board_canvas.dart`'s
  /// hit-testing compares a click's already-board-space position
  /// against.
  static Rect toBoardRect(BoardClip clip, Rect local) =>
      local.shift(Offset(clip.x, clip.y));
}
