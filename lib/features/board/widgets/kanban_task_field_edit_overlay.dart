import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../../../data/local/database.dart';
import '../../../data/models/kanban.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../controllers/kanban_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/kanban_task_geometry.dart';

const double _kTitleRowHeight = 32;
const double _kItemRowHeight = 28;
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
    final effectiveScale = element.screenPinned ? 1.0 : view.scale;
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
    final panelHeight =
        _kTitleRowHeight + (itemCount + 1) * _kItemRowHeight + 16;
    final localRect = Rect.fromLTWH(
      anchor.left,
      anchor.top,
      _kPanelWidth,
      panelHeight,
    );
    final topLeft = element.screenPinned
        ? localRect.topLeft
        : localRect.topLeft * view.scale + view.panOffset;
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
    final siblings =
        tasks.where((t) => t.columnId == task.columnId).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final index = siblings.indexWhere((t) => t.id == task.id);
    return index < 0 ? 0 : index;
  }

  static
      ({KanbanElementRow element, int columnIndex, KanbanTask task})?
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

  void _toggleItem(KanbanTask task, int index) {
    final before = task.checklist;
    final items = [...before.items];
    items[index] = items[index].copyWith(done: !items[index].done);
    _writeChecklist(task.id, before, Checklist(items: items));
  }

  void _renameItem(KanbanTask task, int index, String label) {
    final before = task.checklist;
    if (index >= before.items.length || before.items[index].label == label) {
      return;
    }
    final items = [...before.items];
    items[index] = items[index].copyWith(label: label);
    _writeChecklist(task.id, before, Checklist(items: items));
  }

  void _removeItem(KanbanTask task, int index) {
    final before = task.checklist;
    final items = [...before.items]..removeAt(index);
    _writeChecklist(task.id, before, Checklist(items: items));
  }

  void _addItem(KanbanTask task) {
    final before = task.checklist;
    final newItem = ChecklistItem(id: _uuid.v4(), label: '');
    final after = Checklist(items: [...before.items, newItem]);
    _writeChecklist(task.id, before, after);
  }

  void _close() {
    _commitTitle();
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
      if (_boundTaskId != null) _disposeBinding();
      return const SizedBox.shrink();
    }

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
      _disposeBinding();
      _bind(task);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocusNode?.requestFocus();
      });
    }

    final view = ref.watch(boardViewProvider);
    final rect = KanbanTaskFieldEditOverlay.screenRectFor(ref, taskId, view);
    if (rect == null) return const SizedBox.shrink();

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
                    onSubmitted: (_) => _commitTitle(),
                  ),
                ),
                for (var i = 0; i < task.checklist.items.length; i++)
                  _ChecklistItemRow(
                    key: ValueKey(task.checklist.items[i].id),
                    height: _kItemRowHeight,
                    item: task.checklist.items[i],
                    onToggle: () => _toggleItem(task, i),
                    onRename: (label) => _renameItem(task, i, label),
                    onRemove: () => _removeItem(task, i),
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
  final VoidCallback onToggle;
  final ValueChanged<String> onRename;
  final VoidCallback onRemove;

  const _ChecklistItemRow({
    super.key,
    required this.height,
    required this.item,
    required this.onToggle,
    required this.onRename,
    required this.onRemove,
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
    return SizedBox(
      height: widget.height,
      child: Row(
        children: [
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
                      widget.item.label.isEmpty
                          ? ' '
                          : widget.item.label,
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
    );
  }
}
