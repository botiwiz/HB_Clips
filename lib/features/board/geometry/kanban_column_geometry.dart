import 'package:flutter/rendering.dart';

import '../../../core/constants.dart';
import '../../../data/local/database.dart' show KanbanElementRow;
import 'kanban_element_geometry.dart';

/// Pure geometry for one kanban column's rect/chrome within its parent
/// element. A column has no stored x/width of its own (see
/// `kanban_columns` table doc comment) - every rect here is derived from
/// the column's 0-based left-to-right [index] among its siblings, never
/// from anything persisted on the column row itself.
class KanbanColumnGeometry {
  KanbanColumnGeometry._();

  /// Board-space rect of column [index] within [element] - horizontal
  /// position is always `index * (columnWidth + gap)`, vertical extent
  /// always matches the element's content rect.
  static Rect columnRect(KanbanElementRow element, int index) {
    final content = KanbanElementGeometry.contentRect(element);
    final left =
        content.left +
        kKanbanElementPadding +
        index * (kKanbanColumnWidth + kKanbanColumnGap);
    return Rect.fromLTWH(left, content.top, kKanbanColumnWidth, content.height);
  }

  /// Board-space rect of column [index]'s header band (name + add/delete
  /// chrome), above its task list.
  static Rect headerRect(KanbanElementRow element, int index) {
    final col = columnRect(element, index);
    return Rect.fromLTWH(
      col.left,
      col.top,
      col.width,
      kKanbanColumnHeaderHeight,
    );
  }

  /// Board-space rect of column [index]'s color-swatch button, in its own
  /// header band's top-right corner - same "fixed small icon tucked into
  /// a header" idiom `KanbanElementGeometry.pinToggleRect` uses for the
  /// element's own header.
  static Rect colorSwatchRect(KanbanElementRow element, int index) {
    final header = headerRect(element, index);
    const size = 16.0;
    return Rect.fromLTWH(
      header.right - size - 6,
      header.top + (header.height - size) / 2,
      size,
      size,
    );
  }

  /// Vertical inset (board-space px) a divider line stops short of the
  /// column's own top/bottom edges - keeps it clear of the header band
  /// above and the add-task row below, purely cosmetic.
  static const double _dividerInset = 12;

  /// Board-space divider line between column [index] and the next one, at
  /// the horizontal midpoint of the gap between them - a zero-width `Rect`
  /// (only `top`/`bottom`/`left` are meaningful; callers render a fixed-
  /// width line at `left`, not a board-scaled one, same convention this
  /// widget's borders already follow) inset vertically from the column's
  /// own extent. `null` for the last column (nothing after it to divide).
  static Rect? dividerRect(
    KanbanElementRow element,
    int index,
    int columnCount,
  ) {
    if (index >= columnCount - 1) return null;
    final col = columnRect(element, index);
    final x = col.right + kKanbanColumnGap / 2;
    return Rect.fromLTRB(
      x,
      col.top + _dividerInset,
      x,
      col.bottom - _dividerInset,
    );
  }

  /// Board-space rect of the scrollable task-list viewport, between the
  /// header and the add-task button.
  static Rect taskListViewportRect(KanbanElementRow element, int index) {
    final col = columnRect(element, index);
    return Rect.fromLTWH(
      col.left,
      col.top + kKanbanColumnHeaderHeight,
      col.width,
      col.height - kKanbanColumnHeaderHeight - kKanbanTaskRowMinHeight,
    );
  }

  /// Board-space rect of the fixed `[+]` add-task button at the bottom of
  /// column [index].
  static Rect addTaskButtonRect(KanbanElementRow element, int index) {
    final col = columnRect(element, index);
    return Rect.fromLTWH(
      col.left,
      col.bottom - kKanbanTaskRowMinHeight,
      col.width,
      kKanbanTaskRowMinHeight,
    );
  }

  /// Board-space rect of the "+ Add list" affordance one slot past the
  /// last existing column - a slim [kKanbanAddColumnWidth]-wide strip,
  /// not a full column width, sized to fit inside the element's own
  /// outer bounds (see `KanbanElementGeometry.widthForColumnCount`,
  /// which reserves exactly this much room after the last column).
  static Rect addColumnButtonRect(KanbanElementRow element, int columnCount) {
    final content = KanbanElementGeometry.contentRect(element);
    final left = columnCount <= 0
        ? content.left + kKanbanElementPadding
        : columnRect(element, columnCount - 1).right + kKanbanColumnGap;
    return Rect.fromLTWH(
      left,
      content.top,
      kKanbanAddColumnWidth,
      content.height,
    );
  }

  /// Clamps the task-list scroll offset to `[0, maxScroll]`, where
  /// `maxScroll` is however far [contentHeight] (every row stacked,
  /// un-scrolled) overflows the viewport - 0 if it already fits.
  static double clampScrollOffset(
    KanbanElementRow element,
    int index,
    double rawOffset,
    double contentHeight,
  ) {
    final viewportHeight = taskListViewportRect(element, index).height;
    final maxScroll = (contentHeight - viewportHeight) < 0
        ? 0.0
        : contentHeight - viewportHeight;
    return rawOffset < 0
        ? 0.0
        : (rawOffset > maxScroll ? maxScroll : rawOffset);
  }

  /// Which column index [boardPoint]'s x falls within, among
  /// [columnCount] columns - resolves to the first/last column rather
  /// than null when x is beyond the element's horizontal extent, so a
  /// drag pinned to an edge still resolves to a valid column (see the
  /// Kanban-rebuild plan's rigidity section: the element's outer bounds
  /// are a hard clamp, but columns inside it are freely crossable).
  static int columnIndexForPoint(
    KanbanElementRow element,
    int columnCount,
    Offset boardPoint,
  ) {
    if (columnCount <= 0) return 0;
    final content = KanbanElementGeometry.contentRect(element);
    final relativeX = boardPoint.dx - (content.left + kKanbanElementPadding);
    final slot = (relativeX / (kKanbanColumnWidth + kKanbanColumnGap)).floor();
    if (slot < 0) return 0;
    if (slot > columnCount - 1) return columnCount - 1;
    return slot;
  }
}
