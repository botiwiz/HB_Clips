import 'package:drift/drift.dart';

import '../local/database.dart';
import '../models/kanban.dart';

/// Local read/write API for kanban tasks (Trello-style cards). A task's
/// position is *only* `(columnId, sortOrder)` - no board-space x/y at
/// all, so there is no coordinate a committed task could ever hold that
/// means "outside its element" (see the Kanban-rebuild plan's "rigidity"
/// section).
class KanbanTasksRepository {
  final AppDatabase _db;

  KanbanTasksRepository(this._db);

  /// Watches every task belonging to any column of any kanban element on
  /// [boardId], in one subscription (joined through `kanban_columns` ->
  /// `kanban_elements`) - "watch everything for the parent scope, group/
  /// sort in-memory" convention, same as `watchColumnsForBoard`. Callers
  /// group by `KanbanTask.columnId` and sort by `sortOrder` themselves
  /// (see `KanbanColumnGeometry`).
  Stream<List<KanbanTask>> watchTasksForBoard(String boardId) {
    final query = _db.select(_db.kanbanTasks).join([
      innerJoin(
        _db.kanbanColumns,
        _db.kanbanColumns.id.equalsExp(_db.kanbanTasks.columnId),
      ),
      innerJoin(
        _db.kanbanElements,
        _db.kanbanElements.id.equalsExp(_db.kanbanColumns.kanbanElementId),
      ),
    ])..where(_db.kanbanElements.boardId.equals(boardId));
    return query.watch().map(
      (rows) => rows
          .map((row) => KanbanTask.fromRow(row.readTable(_db.kanbanTasks)))
          .toList(),
    );
  }

  /// `MAX(sortOrder) + 1.0` among [columnId]'s tasks - appends to the
  /// bottom of the column (see the Kanban-rebuild plan's "ordering:
  /// fractional indexing" section).
  Future<double> _nextSortOrder(String columnId) async {
    final query = _db.selectOnly(_db.kanbanTasks)
      ..addColumns([_db.kanbanTasks.sortOrder.max()])
      ..where(_db.kanbanTasks.columnId.equals(columnId));
    final row = await query.getSingleOrNull();
    final maxOrder = row?.read(_db.kanbanTasks.sortOrder.max());
    return (maxOrder ?? 0) + 1.0;
  }

  Future<KanbanTask> addTask({
    required String id,
    required String columnId,
    String title = '',
  }) async {
    final sortOrder = await _nextSortOrder(columnId);
    await _db
        .into(_db.kanbanTasks)
        .insert(
          KanbanTasksCompanion.insert(
            id: id,
            columnId: columnId,
            title: Value(title),
            sortOrder: Value(sortOrder),
          ),
        );
    final row = await (_db.select(
      _db.kanbanTasks,
    )..where((t) => t.id.equals(id))).getSingle();
    return KanbanTask.fromRow(row);
  }

  /// Recreates a task with every field explicit (including [sortOrder]
  /// and [checklist], which [addTask] always computes/defaults instead) -
  /// a low-level primitive for undo/redo's own use (restoring a task
  /// exactly as it was before a column/element delete), not a normal
  /// user-facing entry point. Mirrors `ClipsRepository.setZIndex`'s own
  /// "undo-only primitive" role.
  Future<void> recreateTask({
    required String id,
    required String columnId,
    required String title,
    required Checklist checklist,
    required double sortOrder,
  }) {
    return _db
        .into(_db.kanbanTasks)
        .insert(
          KanbanTasksCompanion.insert(
            id: id,
            columnId: columnId,
            title: Value(title),
            checklistJson: Value(checklist.toJson()),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  Future<void> updateTitle(String id, String title) {
    return (_db.update(_db.kanbanTasks)..where((t) => t.id.equals(id))).write(
      KanbanTasksCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Sets a task's full checklist. Callers write the whole structure each
  /// time (one item toggled, added, renamed, or removed) - same
  /// "whole-document setter" convention `ClipsRepository
  /// .updateTextFormatting` already follows.
  Future<void> updateChecklist(String id, Checklist checklist) {
    return (_db.update(_db.kanbanTasks)..where((t) => t.id.equals(id))).write(
      KanbanTasksCompanion(
        checklistJson: Value(checklist.toJson()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Moves a task to [columnId] at [sortOrder] - the one write a
  /// drag-to-reorder/drag-across-columns gesture commits (position within
  /// a column, and which column, are always set together). The actual
  /// fractional-index math (append/insert-between/before-first/after-last)
  /// lives in `KanbanTaskGeometry`, a pure function the caller resolves
  /// *before* calling this - this method is a plain setter, not where
  /// that decision is made.
  Future<void> moveTask(
    String id, {
    required String columnId,
    required double sortOrder,
  }) {
    return (_db.update(_db.kanbanTasks)..where((t) => t.id.equals(id))).write(
      KanbanTasksCompanion(
        columnId: Value(columnId),
        sortOrder: Value(sortOrder),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Deletes a task, cascading to any `kanban_task_links` rows that
  /// linked it to a clip/frame.
  Future<void> deleteTask(String id) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.kanbanTaskLinks,
      )..where((l) => l.taskId.equals(id))).go();
      await (_db.delete(_db.kanbanTasks)..where((t) => t.id.equals(id))).go();
    });
  }
}
