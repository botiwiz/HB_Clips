import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../controllers/kanban_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/kanban_column_geometry.dart';

/// Inline rename `TextField` shown over a kanban column's header title
/// while [renamingKanbanColumnIdProvider] is set - started by double-
/// clicking a column's header in `board_canvas.dart`'s kanban element
/// hit-test. A direct structural copy of `FrameRenameOverlay`, just
/// scoped to a kanban column and `KanbanColumnsRepository.renameColumn`
/// instead of a frame and `FramesRepository.renameFrame`.
class KanbanColumnRenameOverlay extends ConsumerStatefulWidget {
  const KanbanColumnRenameOverlay({super.key});

  /// Finds the column, its owning kanban element, and its 0-based index
  /// among sortOrder-sorted siblings - null if [columnId] can't currently
  /// be resolved (deleted out from under the rename, undo race). Mirrors
  /// `KanbanTaskFieldEditOverlay._locate`, minus the task lookup.
  static ({KanbanElementRow element, int columnIndex, KanbanColumnRow column})?
  _locate(WidgetRef ref, String columnId) {
    final columns = ref.read(boardKanbanColumnsProvider).valueOrNull ?? [];
    KanbanColumnRow? column;
    for (final c in columns) {
      if (c.id == columnId) {
        column = c;
        break;
      }
    }
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

    final siblingColumns =
        columns.where((c) => c.kanbanElementId == element!.id).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final columnIndex = siblingColumns.indexWhere((c) => c.id == column!.id);
    if (columnIndex < 0) return null;

    return (element: element, columnIndex: columnIndex, column: column);
  }

  /// Screen-space bounds of the open rename field for [columnId] - used
  /// by `board_canvas.dart` as a click-through guard, same role
  /// `FrameRenameOverlay.screenRectFor` plays. Returns null if [columnId]
  /// can't currently be resolved.
  static Rect? screenRectFor(
    WidgetRef ref,
    String columnId,
    BoardViewState view,
  ) {
    final located = _locate(ref, columnId);
    if (located == null) return null;
    final (element: element, columnIndex: columnIndex, column: _) = located;
    // A pinned element's own x/y are already literal screen pixels and
    // renders at a frozen scale of 1.0 - same rule
    // `KanbanTaskFieldEditOverlay.screenRectFor` follows.
    final effectiveElement = element.screenPinned
        ? element.copyWith(
            x: element.pinnedScreenX ?? element.x,
            y: element.pinnedScreenY ?? element.y,
          )
        : element;
    final effectiveScale = element.screenPinned ? 1.0 : view.scale;
    final localRect = KanbanColumnGeometry.headerRect(
      effectiveElement,
      columnIndex,
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

  @override
  ConsumerState<KanbanColumnRenameOverlay> createState() =>
      _KanbanColumnRenameOverlayState();
}

class _KanbanColumnRenameOverlayState
    extends ConsumerState<KanbanColumnRenameOverlay> {
  String? _boundColumnId;
  TextEditingController? _controller;
  FocusNode? _focusNode;
  String _before = '';

  void _bind(KanbanColumnRow column) {
    _boundColumnId = column.id;
    _before = column.name;
    _controller = TextEditingController(text: column.name)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: column.name.length,
      );
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _disposeBinding() {
    _focusNode?.removeListener(_onFocusChange);
    _focusNode?.dispose();
    _controller?.dispose();
    _boundColumnId = null;
    _controller = null;
    _focusNode = null;
  }

  void _onFocusChange() {
    if (_focusNode != null && !_focusNode!.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final id = _boundColumnId;
    final controller = _controller;
    if (id == null || controller == null) return;
    final trimmed = controller.text.trim();
    if (trimmed.isNotEmpty && trimmed != _before) {
      final columnsRepo = ref.read(kanbanColumnsRepositoryProvider);
      final before = _before;
      columnsRepo.renameColumn(id, trimmed);
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => columnsRepo.renameColumn(id, before),
              redo: () => columnsRepo.renameColumn(id, trimmed),
            ),
          );
    }
    ref.read(renamingKanbanColumnIdProvider.notifier).state = null;
  }

  void _cancel() {
    ref.read(renamingKanbanColumnIdProvider.notifier).state = null;
  }

  @override
  void dispose() {
    _disposeBinding();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renamingColumnId = ref.watch(renamingKanbanColumnIdProvider);
    if (renamingColumnId == null) {
      if (_boundColumnId != null) _disposeBinding();
      return const SizedBox.shrink();
    }

    final columns = ref.watch(boardKanbanColumnsProvider).valueOrNull ?? [];
    KanbanColumnRow? column;
    for (final c in columns) {
      if (c.id == renamingColumnId) {
        column = c;
        break;
      }
    }
    if (column == null) {
      // The column disappeared from under the rename (deleted, undo
      // race) - nothing left to rename.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(renamingKanbanColumnIdProvider.notifier).state = null;
      });
      return const SizedBox.shrink();
    }

    if (_boundColumnId != renamingColumnId) {
      _disposeBinding();
      _bind(column);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode?.requestFocus();
      });
    }

    final view = ref.watch(boardViewProvider);
    final rect = KanbanColumnRenameOverlay.screenRectFor(
      ref,
      renamingColumnId,
      view,
    );
    if (rect == null) return const SizedBox.shrink();

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
        child: Material(
          color: Colors.transparent,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            ),
            onSubmitted: (_) => _commit(),
          ),
        ),
      ),
    );
  }
}
