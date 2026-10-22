import 'package:flutter/rendering.dart';

import '../../../data/local/database.dart' show KanbanElementRow;
import '../controllers/board_controller.dart';
import 'kanban_element_geometry.dart';

/// Pure geometry for viewport culling - deciding which clips/frames/kanban
/// elements are worth rendering at all for the current pan/zoom, so
/// `board_canvas.dart`'s `build()` doesn't build (and decode images for)
/// every item on the board regardless of whether it's anywhere near the
/// screen. No widget imports, unit-testable the same way
/// `selection_geometry.dart` is.
class ViewportCulling {
  ViewportCulling._();

  /// Board-space rect covering the current viewport, padded by one
  /// viewport-extent per side - generous enough that a clip doesn't
  /// visibly pop in right as its edge crosses the screen edge during a
  /// fast pan, while still excluding everything far outside the screen.
  static Rect boardRectFor(BoardViewState view, Size canvasSize) {
    final topLeft = (Offset.zero - view.panOffset) / view.scale;
    final bottomRight =
        (Offset(canvasSize.width, canvasSize.height) - view.panOffset) /
        view.scale;
    final raw = Rect.fromPoints(topLeft, bottomRight);
    return Rect.fromLTRB(
      raw.left - raw.width,
      raw.top - raw.height,
      raw.right + raw.width,
      raw.bottom + raw.height,
    );
  }

  /// A screen-pinned kanban element's rect is already expressed in screen
  /// space (see [KanbanElementRow]'s own doc comment), not board space, so
  /// it's always considered visible rather than compared against a
  /// board-space viewport rect - it's pinned to the screen by definition.
  static bool isKanbanElementVisible(
    Rect viewportBoardRect,
    KanbanElementRow element,
  ) {
    if (element.screenPinned) return true;
    return viewportBoardRect.overlaps(KanbanElementGeometry.outerRect(element));
  }
}
