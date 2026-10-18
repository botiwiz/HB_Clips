import 'package:flutter/rendering.dart';

import '../../../core/constants.dart';
import '../../../data/local/database.dart' show KanbanElementRow;
import '../controllers/board_controller.dart' show BoardViewState;

/// Pure geometry for a kanban element's own outer rect/chrome - the
/// rigid, self-contained Trello-parity container (see the Kanban-rebuild
/// plan). Unlike the old `kanban_boards` snapshot, `KanbanElementRow.x/y/
/// width/height` IS authoritative - every rect here is a direct function
/// of the row's own stored fields, nothing is derived from a live union
/// of other board objects the way `SwimlaneGeometry.columnSpanBoardRect`
/// used to be.
class KanbanElementGeometry {
  KanbanElementGeometry._();

  static const double handleHitRadius = 10;

  static Offset _boardToScreen(Offset boardPoint, BoardViewState view) =>
      boardPoint * view.scale + view.panOffset;

  /// Scales a local (unscaled, board/pinned-screen-unit) point around
  /// [element]'s own origin by its per-element [KanbanElementRow.scale] -
  /// the same transform `KanbanElementWidget.local()` applies to every
  /// piece of content it renders, needed here too since a handle's
  /// on-screen position is computed independently of that widget.
  static Offset _scaleAroundOrigin(Offset point, KanbanElementRow element) {
    final origin = Offset(element.x, element.y);
    return origin + (point - origin) * element.scale;
  }

  /// [alreadyScreenSpace] (true for a screen-pinned element passed as its
  /// "effective" row, x/y already literal screen pixels) skips the
  /// board->screen transform, since there's nothing left to transform -
  /// see `board_canvas.dart`'s `_kanbanEffectiveElement` doc comment for
  /// why every kanban geometry function stays coordinate-agnostic like
  /// this instead of branching on pin state itself.
  static Offset resizeHandleScreenPosition(
    KanbanElementRow element,
    BoardViewState view, {
    bool alreadyScreenSpace = false,
  }) {
    final outer = outerRect(element);
    final point = _scaleAroundOrigin(
      Offset(outer.center.dx, outer.bottom),
      element,
    );
    return alreadyScreenSpace ? point : _boardToScreen(point, view);
  }

  static bool hitTestResizeHandle(
    KanbanElementRow element,
    BoardViewState view,
    Offset screenPoint, {
    bool alreadyScreenSpace = false,
  }) {
    return (resizeHandleScreenPosition(
                  element,
                  view,
                  alreadyScreenSpace: alreadyScreenSpace,
                ) -
                screenPoint)
            .distance <=
        handleHitRadius;
  }

  /// Screen position of the free corner-scale handle (see
  /// [scaleHandleRect]) - same `alreadyScreenSpace`/scale-around-origin
  /// treatment as [resizeHandleScreenPosition].
  static Offset scaleHandleScreenPosition(
    KanbanElementRow element,
    BoardViewState view, {
    bool alreadyScreenSpace = false,
  }) {
    final point = _scaleAroundOrigin(outerRect(element).bottomRight, element);
    return alreadyScreenSpace ? point : _boardToScreen(point, view);
  }

  static bool hitTestScaleHandle(
    KanbanElementRow element,
    BoardViewState view,
    Offset screenPoint, {
    bool alreadyScreenSpace = false,
  }) {
    return (scaleHandleScreenPosition(
                  element,
                  view,
                  alreadyScreenSpace: alreadyScreenSpace,
                ) -
                screenPoint)
            .distance <=
        handleHitRadius;
  }

  static Rect outerRect(KanbanElementRow element) =>
      Rect.fromLTWH(element.x, element.y, element.width, element.height);

  /// Board-space rect of the element's own title band, above every
  /// column's header.
  static Rect headerRect(KanbanElementRow element) {
    final outer = outerRect(element);
    return Rect.fromLTWH(
      outer.left,
      outer.top,
      outer.width,
      kKanbanElementHeaderHeight,
    );
  }

  /// Board-space rect of the content area below the header, where
  /// columns are laid out - derived, not stored.
  static Rect contentRect(KanbanElementRow element) {
    final outer = outerRect(element);
    return Rect.fromLTWH(
      outer.left,
      outer.top + kKanbanElementHeaderHeight,
      outer.width,
      outer.height - kKanbanElementHeaderHeight,
    );
  }

  /// Board-space rect of the single bottom-edge resize handle - a short
  /// horizontal strip centered on the element's bottom edge. Height is
  /// the only interactively resizable dimension (width is always derived
  /// from column count via [widthForColumnCount]), so there's no corner
  /// handle the way a Frame has.
  static Rect resizeHandleRect(KanbanElementRow element) {
    final outer = outerRect(element);
    const handleWidth = 40.0;
    const handleHeight = 10.0;
    return Rect.fromLTWH(
      outer.center.dx - handleWidth / 2,
      outer.bottom - handleHeight / 2,
      handleWidth,
      handleHeight,
    );
  }

  /// Board-space rect of the free corner-scale handle, bottom-right -
  /// distinct from [resizeHandleRect] (height-only, bottom-edge centered):
  /// dragging this adjusts [KanbanElementRow.scale] directly, working
  /// identically whether the element is pinned or not (see the table's
  /// own doc comment on `scale`).
  static Rect scaleHandleRect(KanbanElementRow element) {
    final outer = outerRect(element);
    const size = 12.0;
    return Rect.fromLTWH(
      outer.right - size / 2,
      outer.bottom - size / 2,
      size,
      size,
    );
  }

  static bool pointInElement(Offset boardPoint, KanbanElementRow element) =>
      outerRect(element).contains(boardPoint);

  /// Board-space rect of the "pin to screenspace" toggle icon, in the
  /// header band's top-right corner (mirrors `addColumnButtonRect`'s
  /// "+" sitting in the content band - this is the header's own
  /// equivalent affordance, not column-indexed since there's only one).
  static Rect pinToggleRect(KanbanElementRow element) {
    final header = headerRect(element);
    const size = 20.0;
    return Rect.fromLTWH(
      header.right - size - 6,
      header.top + (header.height - size) / 2,
      size,
      size,
    );
  }

  /// The element's authoritative width, derived from [columnCount] -
  /// recomputed and persisted (`KanbanElementsRepository.updateTransform`)
  /// whenever a column is added/removed. Trello's own "lists are a fixed
  /// width, the board scrolls vertically per list" behavior, rather than
  /// a column-reflow-on-resize interaction. Always includes room for the
  /// trailing "+ Add list" slot ([kKanbanAddColumnWidth], plus one more
  /// [kKanbanColumnGap] before it) so that affordance stays inside the
  /// element's own rigid bounds instead of past its clipped edge - see
  /// `KanbanColumnGeometry.addColumnButtonRect`.
  static double widthForColumnCount(int columnCount) {
    if (columnCount <= 0) {
      return 2 * kKanbanElementPadding + kKanbanAddColumnWidth;
    }
    return 2 * kKanbanElementPadding +
        columnCount * kKanbanColumnWidth +
        columnCount * kKanbanColumnGap +
        kKanbanAddColumnWidth;
  }
}
