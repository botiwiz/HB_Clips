import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hsv_color_picker.dart';
import '../../../data/local/database.dart';
import '../../../data/models/kanban.dart';
import '../../../data/providers.dart';
import '../../annotation/stroke_painter.dart' show colorToHex, hexToColor;
import '../controllers/board_controller.dart';
import '../controllers/kanban_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/kanban_task_geometry.dart';

const double _kTitleRowHeight = 32;
const double _kItemRowHeight = 28;
const double _kColorPickerHeight = 44;
const double _kPanelWidth = kKanbanColumnWidth;
const _uuid = Uuid();

/// A kanban task's expanded detail/edit view - shown over its (fixed-
/// height, title-only) row in the column while
/// `editingKanbanTaskFieldProvider` names it. This is where the title AND
/// the task's checklist actually get edited (add/toggle/rename/remove
/// items) - Trello's own "collapsed card in the list, bigger detail view
/// on click" split, chosen specifically so a column's row height/scroll
/// math never has to account for a variable-height checklist inline in
/// the list (see `KanbanColumnGeometry`/`KanbanTaskGeometry`, both fixed-
/// row-height throughout). Unlike `ClipWidget`/`KanbanElementWidget`,
/// this overlay is a real Flutter widget tree with real interactivity -
/// same "two exceptions that do need a real TextField" precedent
/// `TextClipEditOverlay`/the old `KanbanCardFieldEditOverlay` already
/// established, just covering a whole task's title+checklist at once
/// instead of one field.
class KanbanTaskFieldEditOverlay extends ConsumerStatefulWidget {
  const KanbanTaskFieldEditOverlay({super.key});

  /// Screen-space bounds of the open panel for [taskId] - used by
  /// `board_canvas.dart` as a click-through guard, same role
  /// `FrameRenameOverlay.screenRectFor` plays. Returns null if [taskId]
  /// can't currently be resolved to a row (deleted out from under the
  /// overlay, undo race).
  static Rect? screenRectFor(
    WidgetRef ref,
    String taskId,
    BoardViewState view,
  ) {
    final located = _locate(ref, taskId);
    if (located == null) return null;
    final (element: element, columnIndex: columnIndex, task: task) = located;
    // A pinned element's own x/y are already literal screen pixels (see
    // the table's own doc comment) and renders at a frozen scale of
    // 1.0 - same "skip the board->screen transform entirely" rule
    // `board_canvas.dart`'s `_kanbanEffectiveElement`/
    // `_positionedKanbanElement` follow.
    final effectiveElement = element.screenPinned
        ? element.copyWith(
            x: element.pinnedScreenX ?? element.x,
            y: element.pinnedScreenY ?? element.y,
          )
        : element;
    final effectiveScale =
        (element.screenPinned ? 1.0 : view.scale) * element.scale;
    final scrollOffsets = ref.read(kanbanColumnScrollOffsetProvider);
    final column = _columnRowFor(ref, task.columnId);
    final scrollOffset = column == null
        ? 0.0
        : (scrollOffsets[column.id] ?? 0.0);
    final rowIndex = _rowIndexFor(ref, task);
    final anchor = KanbanTaskGeometry.taskRowRect(
      effectiveElement,
      columnIndex,
      rowIndex,
      scrollOffset,
    );
    final itemCount = task.checklist.items.length;
    final colorPickerOpen = ref.read(kanbanTaskColorPickerOpenProvider);
    final panelHeight =
        _kTitleRowHeight +
        (colorPickerOpen ? _kColorPickerHeight : 0) +
        (itemCount + 1) * _kItemRowHeight +
        16;
    final localRect = Rect.fromLTWH(
      anchor.left,
      anchor.top,
      _kPanelWidth,
      panelHeight,
    );
    // See `KanbanColumnRenameOverlay.screenRectFor`'s own comment: the
    // rect's screen position is the element's own screen-space origin
    // plus its local offset from that origin, scaled - not a flat
    // board->screen transform of the rect's own coordinates.
    final elementOrigin = Offset(effectiveElement.x, effectiveElement.y);
    final boxTopLeft = element.screenPinned
        ? elementOrigin
        : elementOrigin * view.scale + view.panOffset;
    final topLeft =
        boxTopLeft + (localRect.topLeft - elementOrigin) * effectiveScale;
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      localRect.width * effectiveScale,
      localRect.height * effectiveScale,
    );
  }

  static KanbanColumnRow? _columnRowFor(WidgetRef ref, String columnId) {
    final columns = ref.read(boardKanbanColumnsProvider).valueOrNull ?? [];
    for (final c in columns) {
      if (c.id == columnId) return c;
    }
    return null;
  }

  static int _rowIndexFor(WidgetRef ref, KanbanTask task) {
    final tasks = ref.read(boardKanbanTasksProvider).valueOrNull ?? [];
    final siblings = tasks.where((t) => t.columnId == task.columnId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final index = siblings.indexWhere((t) => t.id == task.id);
    return index < 0 ? 0 : index;
  }

  static ({KanbanElementRow element, int columnIndex, KanbanTask task})?
  _locate(WidgetRef ref, String taskId) {
    final tasks = ref.read(boardKanbanTasksProvider).valueOrNull ?? [];
    KanbanTask? task;
    for (final t in tasks) {
      if (t.id == taskId) {
        task = t;
        break;
      }
    }
    if (task == null) return null;

    final column = _columnRowFor(ref, task.columnId);
    if (column == null) return null;

    final elements = ref.read(boardKanbanElementsProvider).valueOrNull ?? [];
    KanbanElementRow? element;
    for (final e in elements) {
      if (e.id == column.kanbanElementId) {
        element = e;
        break;
      }
    }
    if (element == null) return null;

    final columns = ref.read(boardKanbanColumnsProvider).valueOrNull ?? [];
    final siblingColumns =
        columns.where((c) => c.kanbanElementId == element!.id).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final columnIndex = siblingColumns.indexWhere((c) => c.id == column.id);
    if (columnIndex < 0) return null;

    return (element: element, columnIndex: columnIndex, task: task);
  }

  @override
  ConsumerState<KanbanTaskFieldEditOverlay> createState() =>
      _KanbanTaskFieldEditOverlayState();
}

class _KanbanTaskFieldEditOverlayState
    extends ConsumerState<KanbanTaskFieldEditOverlay> {
  String? _boundTaskId;
  TextEditingController? _titleController;
  FocusNode? _titleFocusNode;
  String _titleBefore = '';
  String? _colorBeforePicker;

  void _bind(KanbanTask task) {
    _boundTaskId = task.id;
    _titleBefore = task.title;
    _titleController = TextEditingController(text: _titleBefore)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleBefore.length,
      );
    _titleFocusNode = FocusNode()..addListener(_onTitleFocusChange);
  }

  void _disposeBinding() {
    _titleFocusNode?.removeListener(_onTitleFocusChange);
    _titleFocusNode?.dispose();
    _titleController?.dispose();
    _boundTaskId = null;
    _titleController = null;
    _titleFocusNode = null;
  }

  void _onTitleFocusChange() {
    if (_titleFocusNode != null && !_titleFocusNode!.hasFocus) {
      _commitTitle();
    }
  }

  void _commitTitle() {
    final id = _boundTaskId;
    final controller = _titleController;
    if (id == null || controller == null) return;
    final trimmed = controller.text.trim();
    if (trimmed == _titleBefore) return;
    final before = _titleBefore;
    final repo = ref.read(kanbanTasksRepositoryProvider);
    repo.updateTitle(id, trimmed);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => repo.updateTitle(id, before),
            redo: () => repo.updateTitle(id, trimmed),
          ),
        );
    _titleBefore = trimmed;
  }

  /// Closes the inline color picker (if open), pushing one undo step if
  /// the color actually changed while it was open - mirrors
  /// `ShapeStylePopover._closePickers`'s single-picker case. Safe to call
  /// with a since-deleted/switched-away-from task id (the repository
  /// write below just no-ops against zero rows).
  void _commitColor(String taskId) {
    if (!ref.read(kanbanTaskColorPickerOpenProvider)) return;
    final before = _colorBeforePicker;
    _colorBeforePicker = null;
    ref.read(kanbanTaskColorPickerOpenProvider.notifier).state = false;
    final tasks = ref.read(boardKanbanTasksProvider).valueOrNull ?? [];
    String? after;
    for (final t in tasks) {
      if (t.id == taskId) {
        after = t.colorHex;
        break;
      }
    }
    if (before == after) return;
    final repo = ref.read(kanbanTasksRepositoryProvider);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => repo.updateColor(taskId, before),
            redo: () => repo.updateColor(taskId, after),
          ),
        );
  }

  void _toggleColorPicker(KanbanTask task) {
    if (ref.read(kanbanTaskColorPickerOpenProvider)) {
      _commitColor(task.id);
      return;
    }
    _colorBeforePicker = task.colorHex;
    ref.read(kanbanTaskColorPickerOpenProvider.notifier).state = true;
  }

  void _writeChecklist(String taskId, Checklist before, Checklist after) {
    final repo = ref.read(kanbanTasksRepositoryProvider);
    repo.updateChecklist(taskId, after);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => repo.updateChecklist(taskId, before),
            redo: () => repo.updateChecklist(taskId, after),
          ),
        );
  }

  /// Toggling moves the item instead of leaving it in place: becoming
  /// done sends it to the very bottom of the list (below every other
  /// item, done or not); becoming undone returns it to the bottom of the
  /// *active* run - i.e. "back into the stack" - rather than its old
  /// position, which there's nothing left to remember once the list has
  /// been reordered. This keeps the list always shaped as
  /// `[...active, ...done]`, the invariant `_reorderWithinGroup` (drag
  /// reorder) relies on to find each item's own group boundaries.
  void _toggleItem(KanbanTask task, String itemId) {
    final before = task.checklist;
    final items = [...before.items];
    final index = items.indexWhere((i) => i.id == itemId);
    if (index < 0) return;
    final item = items.removeAt(index);
    final toggled = item.copyWith(done: !item.done);
    if (toggled.done) {
      items.add(toggled);
    } else {
      final activeCount = items.where((i) => !i.done).length;
      items.insert(activeCount, toggled);
    }
    _writeChecklist(task.id, before, Checklist(items: items));
  }

  void _renameItem(KanbanTask task, String itemId, String label) {
    final before = task.checklist;
    final index = before.items.indexWhere((i) => i.id == itemId);
    if (index < 0 || before.items[index].label == label) return;
    final items = [...before.items];
    items[index] = items[index].copyWith(label: label);
    _writeChecklist(task.id, before, Checklist(items: items));
  }

  void _removeItem(KanbanTask task, String itemId) {
    final before = task.checklist;
    final items = [...before.items]..removeWhere((i) => i.id == itemId);
    _writeChecklist(task.id, before, Checklist(items: items));
  }

  void _addItem(KanbanTask task) {
    final before = task.checklist;
    final newItem = ChecklistItem(id: _uuid.v4(), label: '');
    final after = Checklist(items: [...before.items, newItem]);
    _writeChecklist(task.id, before, after);
  }

  // --- Drag-to-reorder -------------------------------------------------
  // Local (non-Riverpod) drag state - purely this overlay's own concern,
  // same "plain State field, not a provider" convention `_titleController`
  // etc. already follow. Reordering is constrained within the dragged
  // item's own done/undone group (never crosses the active/done boundary
  // `_toggleItem` maintains) so manual dragging can never fight the
  // automatic check/uncheck-moves-it grouping.
  int? _draggingItemIndex;
  double _dragAccumDy = 0;
  List<ChecklistItem>? _dragPreviewItems;

  void _dragStart(KanbanTask task, int index) {
    setState(() {
      _draggingItemIndex = index;
      _dragAccumDy = 0;
      _dragPreviewItems = [...task.checklist.items];
    });
  }

  void _dragUpdate(double dy) {
    final items = _dragPreviewItems;
    final from = _draggingItemIndex;
    if (items == null || from == null) return;
    _dragAccumDy += dy;
    final shift = (_dragAccumDy / _kItemRowHeight).round();
    if (shift == 0) return;
    final item = items[from];
    final firstDoneIndex = items.indexWhere((i) => i.done);
    final groupStart = item.done
        ? (firstDoneIndex < 0 ? 0 : firstDoneIndex)
        : 0;
    final groupEnd = item.done
        ? items.length
        : (firstDoneIndex < 0 ? items.length : firstDoneIndex);
    final to = (from + shift).clamp(groupStart, groupEnd - 1);
    if (to == from) return;
    setState(() {
      items.removeAt(from);
      items.insert(to, item);
      _draggingItemIndex = to;
      _dragAccumDy -= (to - from) * _kItemRowHeight;
    });
  }

  void _dragEnd(KanbanTask task) {
    final items = _dragPreviewItems;
    setState(() {
      _draggingItemIndex = null;
      _dragAccumDy = 0;
      _dragPreviewItems = null;
    });
    if (items == null) return;
    final before = task.checklist;
    _writeChecklist(task.id, before, Checklist(items: items));
  }

  /// Deletes the whole task - no confirmation dialog, same "undo is the
  /// safety net" convention every other kanban delete in this app follows.
  /// Any `kanban_task_links` rows this task held are gone too
  /// (`KanbanTasksRepository.deleteTask` cascades them), so undo recreates
  /// both the task and those links in one combined action.
  void _deleteTask(KanbanTask task) {
    final tasksRepo = ref.read(kanbanTasksRepositoryProvider);
    final linksRepo = ref.read(kanbanTaskLinksRepositoryProvider);
    final taskLinks = (ref.read(boardKanbanTaskLinksProvider).valueOrNull ?? [])
        .where((l) => l.taskId == task.id)
        .toList();
    final checklist = task.checklist;
    tasksRepo.deleteTask(task.id);
    ref.read(editingKanbanTaskFieldProvider.notifier).state = null;
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () async {
              await tasksRepo.recreateTask(
                id: task.id,
                columnId: task.columnId,
                title: task.title,
                checklist: checklist,
                sortOrder: task.sortOrder,
                colorHex: task.colorHex,
              );
              if (taskLinks.isNotEmpty) {
                await linksRepo.addLinks([
                  for (final l in taskLinks)
                    (
                      id: l.id,
                      taskId: l.taskId,
                      clipId: l.clipId,
                      frameId: l.frameId,
                    ),
                ]);
              }
            },
            redo: () => tasksRepo.deleteTask(task.id),
          ),
        );
  }

  void _close() {
    _commitTitle();
    if (_boundTaskId != null) _commitColor(_boundTaskId!);
    ref.read(editingKanbanTaskFieldProvider.notifier).state = null;
  }

  @override
  void dispose() {
    _disposeBinding();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskId = ref.watch(editingKanbanTaskFieldProvider);
    if (taskId == null) {
      if (_boundTaskId != null) {
        _commitColor(_boundTaskId!);
        _disposeBinding();
      }
      return const SizedBox.shrink();
    }

    // Subscribed here (not just inside the static, read-only `_locate`
    // helper, which is also called from outside this widget's build
    // context by `screenRectFor`) so that a checklist/title/column/element
    // change elsewhere actually triggers a rebuild of this overlay - a
    // previous version of this file omitted these watches entirely, so
    // edits written via `_writeChecklist` (add/toggle/rename/remove item)
    // landed in the DB but never appeared here until the overlay was
    // closed and reopened.
    ref.watch(boardKanbanTasksProvider);
    ref.watch(boardKanbanColumnsProvider);
    ref.watch(boardKanbanElementsProvider);

    final located = KanbanTaskFieldEditOverlay._locate(ref, taskId);
    if (located == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(editingKanbanTaskFieldProvider.notifier).state = null;
        }
      });
      return const SizedBox.shrink();
    }
    final task = located.task;

    if (_boundTaskId != task.id) {
      if (_boundTaskId != null) _commitColor(_boundTaskId!);
      _disposeBinding();
      _bind(task);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocusNode?.requestFocus();
      });
    }

    final view = ref.watch(boardViewProvider);
    final colorPickerOpen = ref.watch(kanbanTaskColorPickerOpenProvider);
    final rect = KanbanTaskFieldEditOverlay.screenRectFor(ref, taskId, view);
    if (rect == null) return const SizedBox.shrink();
    final taskColor = task.colorHex != null ? hexToColor(task.colorHex!) : null;

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: Material(
          elevation: 8,
          color: const Color(0xFF1E1E22),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _kTitleRowHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                          ),
                          // Supplying our own (no-op) onEditingComplete
                          // suppresses TextField's default Enter behavior
                          // of unfocusing before calling onSubmitted - that
                          // default unfocus was firing _onTitleFocusChange
                          // (a first, real _commitTitle()) immediately
                          // followed by onSubmitted's own call (a second,
                          // harmless no-op one), and the resulting focus
                          // loss was the trigger for this overlay closing
                          // on Enter instead of just committing the title.
                          onEditingComplete: () {},
                          onSubmitted: (_) => _commitTitle(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InlineColorPickerSwatch(
                        color: taskColor ?? AppTheme.surfaceElevated,
                        open: colorPickerOpen,
                        onTap: () => _toggleColorPicker(task),
                        size: 24,
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Delete task',
                        child: InkWell(
                          onTap: () => _deleteTask(task),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (colorPickerOpen)
                  SizedBox(
                    height: _kColorPickerHeight,
                    child: InlineHsvPickerBar(
                      initialColor: taskColor ?? AppTheme.surfaceCard,
                      onChanged: (color) {
                        ref
                            .read(kanbanTasksRepositoryProvider)
                            .updateColor(task.id, colorToHex(color));
                      },
                      onDone: () => _toggleColorPicker(task),
                    ),
                  ),
                for (
                  var i = 0;
                  i < (_dragPreviewItems ?? task.checklist.items).length;
                  i++
                )
                  _ChecklistItemRow(
                    key: ValueKey(
                      (_dragPreviewItems ?? task.checklist.items)[i].id,
                    ),
                    height: _kItemRowHeight,
                    item: (_dragPreviewItems ?? task.checklist.items)[i],
                    dragging: _draggingItemIndex == i,
                    onToggle: () => _toggleItem(
                      task,
                      (_dragPreviewItems ?? task.checklist.items)[i].id,
                    ),
                    onRename: (label) => _renameItem(
                      task,
                      (_dragPreviewItems ?? task.checklist.items)[i].id,
                      label,
                    ),
                    onRemove: () => _removeItem(
                      task,
                      (_dragPreviewItems ?? task.checklist.items)[i].id,
                    ),
                    onDragStart: () => _dragStart(task, i),
                    onDragUpdate: _dragUpdate,
                    onDragEnd: () => _dragEnd(task),
                  ),
                SizedBox(
                  height: _kItemRowHeight,
                  child: TextButton(
                    onPressed: () => _addItem(task),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('+ Add item', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecklistItemRow extends StatefulWidget {
  final double height;
  final ChecklistItem item;
  final bool dragging;
  final VoidCallback onToggle;
  final ValueChanged<String> onRename;
  final VoidCallback onRemove;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  const _ChecklistItemRow({
    super.key,
    required this.height,
    required this.item,
    required this.dragging,
    required this.onToggle,
    required this.onRename,
    required this.onRemove,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<_ChecklistItemRow> createState() => _ChecklistItemRowState();
}

class _ChecklistItemRowState extends State<_ChecklistItemRow> {
  bool _editing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.label);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    setState(() => _editing = false);
    widget.onRename(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.dragging ? 0.6 : 1.0,
      child: SizedBox(
        height: widget.height,
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => widget.onDragStart(),
              onVerticalDragUpdate: (details) =>
                  widget.onDragUpdate(details.delta.dy),
              onVerticalDragEnd: (_) => widget.onDragEnd(),
              child: const Icon(
                Icons.drag_handle,
                size: 14,
                color: Colors.white38,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: widget.onToggle,
              child: Icon(
                widget.item.done
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _editing
                  ? TextField(
                      controller: _controller,
                      autofocus: true,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _commit(),
                      onTapOutside: (_) => _commit(),
                    )
                  : InkWell(
                      onTap: () => setState(() => _editing = true),
                      child: Text(
                        widget.item.label.isEmpty ? ' ' : widget.item.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          decoration: widget.item.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
            ),
            InkWell(
              onTap: widget.onRemove,
              child: const Icon(Icons.close, size: 14, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
