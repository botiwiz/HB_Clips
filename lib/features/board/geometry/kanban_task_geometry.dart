import 'package:flutter/rendering.dart';

import '../../../core/constants.dart';
import '../../../data/local/database.dart' show KanbanElementRow;
import 'kanban_column_geometry.dart';

/// Pure geometry for kanban task rows, drag-clamping, and fractional-index
/// ordering math - the Kanban-rebuild plan's "rigidity" and "ordering"
/// sections implemented as testable pure functions, shared by
/// `KanbanElementWidget` (drawing) and `board_canvas.dart`'s drag
/// handling (hit-testing, live clamp, and the insertion point a drag
/// commits to).
class KanbanTaskGeometry {
  KanbanTaskGeometry._();

  /// Board-space rect of task row [rowIndex] (0-based, top to bottom
  /// after sorting by `sortOrder`) within column [columnIndex]'s task-list
  /// viewport, adjusted by [scrollOffset] (board-space pixels scrolled
  /// down, always >= 0).
  static Rect taskRowRect(
    KanbanElementRow element,
    int columnIndex,
    int rowIndex,
    double scrollOffset,
  ) {
    final viewport = KanbanColumnGeometry.taskListViewportRect(
      element,
      columnIndex,
    );
    return Rect.fromLTWH(
      viewport.left,
      viewport.top + rowIndex * kKanbanTaskRowMinHeight - scrollOffset,
      viewport.width,
      kKanbanTaskRowMinHeight,
    );
  }

  /// Clamps [rawCenter] to stay within [elementContentRect] on every
  /// axis - applied to the drag ghost's rendered position every
  /// pointer-move frame, *before paint*, so a task can never be dragged
  /// (not even visually, mid-gesture) outside its element's opaque
  /// bounds. See the Kanban-rebuild plan's "rigidity" section - this is
  /// the one constraint; crossing column boundaries *inside* that clamp
  /// is a separate, deliberately unrestricted concern (see
  /// `KanbanColumnGeometry.columnIndexForPoint`).
  static Offset clampGhostCenter(Rect elementContentRect, Offset rawCenter) {
    final dx = rawCenter.dx < elementContentRect.left
        ? elementContentRect.left
        : (rawCenter.dx > elementContentRect.right
              ? elementContentRect.right
              : rawCenter.dx);
    final dy = rawCenter.dy < elementContentRect.top
        ? elementContentRect.top
        : (rawCenter.dy > elementContentRect.bottom
              ? elementContentRect.bottom
              : rawCenter.dy);
    return Offset(dx, dy);
  }

  /// Which row index (0-based - "insert before this many existing tasks")
  /// [clampedBoardPoint] resolves to within a column holding
  /// [existingCount] tasks already - the nearest gap between rows,
  /// including "before the first" (0) and "after the last"
  /// ([existingCount]).
  static int insertionIndexForPoint(
    KanbanElementRow element,
    int columnIndex,
    int existingCount,
    double scrollOffset,
    Offset clampedBoardPoint,
  ) {
    final viewport = KanbanColumnGeometry.taskListViewportRect(
      element,
      columnIndex,
    );
    final relativeY = clampedBoardPoint.dy - viewport.top + scrollOffset;
    final index = (relativeY / kKanbanTaskRowMinHeight).round();
    if (index < 0) return 0;
    if (index > existingCount) return existingCount;
    return index;
  }

  /// Fractional `sortOrder` for inserting a task at [insertionIndex]
  /// among [sortedSiblingOrders] (the already-ascending-sorted
  /// `sortOrder` values of every OTHER task currently in the destination
  /// column) - see the Kanban-rebuild plan's "ordering: fractional
  /// indexing" section. Appending past the end is `last + 1.0`;
  /// inserting before the first is `first - 1.0`; inserting between two
  /// existing tasks is their midpoint; an empty column starts at 0.
  static double sortOrderForInsertion(
    List<double> sortedSiblingOrders,
    int insertionIndex,
  ) {
    if (sortedSiblingOrders.isEmpty) return 0;
    if (insertionIndex <= 0) return sortedSiblingOrders.first - 1.0;
    if (insertionIndex >= sortedSiblingOrders.length) {
      return sortedSiblingOrders.last + 1.0;
    }
    final before = sortedSiblingOrders[insertionIndex - 1];
    final after = sortedSiblingOrders[insertionIndex];
    return (before + after) / 2;
  }
}
