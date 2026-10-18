import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ephemeral (session-only, never persisted) state for the kanban element
/// feature - gesture-in-progress previews and one-shot "armed tool"
/// providers, same conventions `board_controller.dart` already uses for
/// every other clip/frame tool and drag. Kept in its own file since the
/// old `board_controller.dart` kanban providers (one-shot card tool,
/// inline-edit target, connector-arrow link source) were fully discarded
/// by the Kanban-to-Trello rebuild, not extended in place - see the
/// rebuild plan's "fate of existing kanban code" section.

/// The kanban element currently selected as one rigid unit (click its
/// header/background, not a task inside it) - null when none. A kanban
/// element is never part of the generic `selectedClipIdsProvider`/
/// `selectedFrameIdsProvider` sets; it has its own, single-id selection
/// slot, since it always moves/resizes/deletes as one indivisible object,
/// never mixed into a multi-select the way frames/clips can be.
final selectedKanbanElementIdProvider = StateProvider<String?>((ref) => null);

/// Ephemeral, not-yet-persisted live rect of the selected kanban element
/// while it's being dragged as one unit - same "render this instead of
/// the DB value, commit on release" role `frameDragRectsProvider` plays
/// for frames.
final kanbanElementDragRectProvider = StateProvider<Rect?>((ref) => null);

/// Ephemeral, not-yet-persisted live rect of the selected kanban element
/// while its bottom-edge handle is being dragged to resize its height -
/// same role `frameResizeRectProvider` plays for a lone frame's own
/// corner handle.
final kanbanElementResizeRectProvider = StateProvider<Rect?>((ref) => null);

/// Per-column vertical scroll offset (board-space pixels, >= 0) for
/// columns whose task list overflows the element's height - keyed by
/// column id. Deliberately ephemeral/unpersisted (unlike every other
/// piece of kanban state) since it's pure view state, the same way the
/// board's own pan/zoom would be if it weren't separately persisted per
/// board - see `KanbanColumnGeometry.clampScrollOffset`.
final kanbanColumnScrollOffsetProvider = StateProvider<Map<String, double>>(
  (ref) => const {},
);

/// Snapshot of an in-progress task drag - null when none is active.
/// [clampedCenter] is already run through `KanbanTaskGeometry
/// .clampGhostCenter` by the caller before being stored here, so every
/// consumer (the ghost renderer, the drop-target column highlight) reads
/// an already-bounded position with no further clamping of its own to
/// get right.
class DraggingTask {
  final String taskId;
  final String kanbanElementId;
  final int columnIndex;
  final int insertionIndex;
  final Offset clampedCenter;

  const DraggingTask({
    required this.taskId,
    required this.kanbanElementId,
    required this.columnIndex,
    required this.insertionIndex,
    required this.clampedCenter,
  });
}

final draggingTaskProvider = StateProvider<DraggingTask?>((ref) => null);

/// Id of the kanban task currently expanded into its detail/edit overlay
/// (`KanbanTaskFieldEditOverlay`) - null when none. A task row in its
/// column stays a fixed-height, title-only list item (Trello's own
/// collapsed-card shape); clicking it opens this overlay, which is where
/// the title AND the task's checklist actually get edited - same
/// "click a card, a bigger detail view opens" split Trello itself uses,
/// chosen specifically so a column's row height/scroll math never has to
/// account for a variable-height expanded checklist inline in the list.
final editingKanbanTaskFieldProvider = StateProvider<String?>((ref) => null);

/// Id of the column whose `KanbanColumnColorPopover` is currently open -
/// null when none. Doubles as "which swatch shows the open-accent ring"
/// and "which column the popover is anchored to" - a column has only one
/// swatch (unlike a shape's fill/stroke pair), so there's no separate
/// boolean needed alongside the id.
final kanbanColumnColorPickerOpenForProvider = StateProvider<String?>(
  (ref) => null,
);

/// Whether the currently-open `KanbanTaskFieldEditOverlay`'s inline
/// color-picker bar is expanded - same role `shapeFillPickerOpenProvider`
/// plays for `ShapeStylePopover`, just a single swatch instead of a
/// fill/stroke pair. Only meaningful while `editingKanbanTaskFieldProvider`
/// is non-null.
final kanbanTaskColorPickerOpenProvider = StateProvider<bool>((ref) => false);

/// Id of the kanban column currently being inline-renamed via
/// `KanbanColumnRenameOverlay` - null when none. Started by double-
/// clicking a column's header title in `board_canvas.dart`'s kanban
/// element hit-test, same role `renamingFrameIdProvider` plays for a
/// frame's title.
final renamingKanbanColumnIdProvider = StateProvider<String?>((ref) => null);

/// One selectable row in an open `ContextMenuOverlay` - [onSelected] is a
/// plain closure the caller builds with whatever context it needs already
/// captured, so the overlay itself stays generic (it has no kanban-
/// specific knowledge at all) and can be reused for the right-click
/// "Link to task..." entry point, the "pick which kanban element"
/// follow-up picker, the "pick which linked task" reverse-navigation
/// picker, and any future right-click action, without a new provider or
/// widget each time.
class ContextMenuItem {
  final String label;
  final VoidCallback onSelected;

  const ContextMenuItem({required this.label, required this.onSelected});
}

/// A pending right-click/picker context menu - null when none is open.
class ContextMenuRequest {
  final Offset screenPosition;
  final List<ContextMenuItem> items;

  const ContextMenuRequest({
    required this.screenPosition,
    required this.items,
  });
}

final contextMenuProvider = StateProvider<ContextMenuRequest?>((ref) => null);

/// Armed by "Link to task..." and held through the camera pan to the
/// kanban board - the one "arm, use once" provider in this app that
/// spans an animation rather than resolving on the very next click. The
/// next click that lands on a task creates one `kanban_task_links` row
/// per id in [clipIds]/[frameIds] (bulk-link for a multi-selection,
/// exactly one row for a single selection); a click that misses every
/// task just clears this (cancel) without creating anything - same
/// cancel-on-miss contract the old `kanbanLinkSourceProvider` connector-
/// arrow tool followed.
final linkToTaskSourceProvider =
    StateProvider<({Set<String> clipIds, Set<String> frameIds})?>(
      (ref) => null,
    );
