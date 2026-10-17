import 'package:drift/drift.dart';

import '../local/database.dart';

/// Local read/write API for kanban elements - the rigid, self-contained
/// Trello-parity container (see the Kanban-rebuild plan). Deleting an
/// element cascades all the way down through its columns, their tasks,
/// and any links those tasks held - unlike a Frame's unparent-not-delete
/// cascade, nothing here survives: a column/task only ever exists as part
/// of exactly one element, there's no "detach and keep" concept for them.
class KanbanElementsRepository {
  final AppDatabase _db;

  KanbanElementsRepository(this._db);

  Stream<List<KanbanElementRow>> watchKanbanElements(String boardId) {
    final query = _db.select(_db.kanbanElements)
      ..where((e) => e.boardId.equals(boardId))
      ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]);
    return query.watch();
  }

  Future<KanbanElementRow> createKanbanElement({
    required String id,
    required String boardId,
    required String name,
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    await _db
        .into(_db.kanbanElements)
        .insert(
          KanbanElementsCompanion.insert(
            id: id,
            boardId: boardId,
            name: Value(name),
            x: Value(x),
            y: Value(y),
            width: Value(width),
            height: Value(height),
          ),
        );
    return (_db.select(
      _db.kanbanElements,
    )..where((e) => e.id.equals(id))).getSingle();
  }

  /// Recreates an element with every field explicit, including
  /// [screenPinned]/[pinnedScreenX]/[pinnedScreenY] - a low-level
  /// primitive for undo/redo's own use (restoring an element exactly as
  /// it was before a delete, pinned or not), not a normal user-facing
  /// entry point. Mirrors `KanbanTasksRepository.recreateTask`'s own
  /// "undo-only primitive" role.
  Future<void> recreateKanbanElement({
    required String id,
    required String boardId,
    required String name,
    required double x,
    required double y,
    required double width,
    required double height,
    required bool screenPinned,
    double? pinnedScreenX,
    double? pinnedScreenY,
  }) {
    return _db
        .into(_db.kanbanElements)
        .insert(
          KanbanElementsCompanion.insert(
            id: id,
            boardId: boardId,
            name: Value(name),
            x: Value(x),
            y: Value(y),
            width: Value(width),
            height: Value(height),
            screenPinned: Value(screenPinned),
            pinnedScreenX: Value(pinnedScreenX),
            pinnedScreenY: Value(pinnedScreenY),
          ),
        );
  }

  Future<void> renameKanbanElement(String id, String name) {
    return (_db.update(
      _db.kanbanElements,
    )..where((e) => e.id.equals(id))).write(
      KanbanElementsCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Updates the element's own rect - unlike the old `kanban_boards`
  /// snapshot, this IS authoritative geometry, so every field is a real
  /// write, not a derived-elsewhere convenience. [width] normally comes
  /// from column count (see `KanbanColumnGeometry`), not an interactive
  /// resize - only [height] has a user-facing resize handle - but both
  /// are accepted here since whole-element drag also needs to persist
  /// [x]/[y] through the same method.
  Future<void> updateTransform(
    String id, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return (_db.update(
      _db.kanbanElements,
    )..where((e) => e.id.equals(id))).write(
      KanbanElementsCompanion(
        x: x != null ? Value(x) : const Value.absent(),
        y: y != null ? Value(y) : const Value.absent(),
        width: width != null ? Value(width) : const Value.absent(),
        height: height != null ? Value(height) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Toggles "pin to screenspace". The caller converts the element's
  /// current on-screen position into the new coordinate system's value
  /// *before* calling this - `boardToScreen(x, y)` into [pinnedScreenX]/
  /// [pinnedScreenY] when pinning on, `screenToBoard(pinnedScreenX,
  /// pinnedScreenY)` into [x]/[y] when pinning off - so the element never
  /// visibly jumps at the instant of toggling. Only the field matching
  /// the *new* state is written; the other pair is simply left as
  /// whatever it was (stale, unused until the element is pinned/unpinned
  /// again) - see the table's own doc comment for why x/y and
  /// pinnedScreenX/Y are kept as two separate coordinate pairs rather
  /// than one reinterpreted one.
  Future<void> setScreenPinned(
    String id, {
    required bool pinned,
    double? x,
    double? y,
    double? pinnedScreenX,
    double? pinnedScreenY,
  }) {
    return (_db.update(
      _db.kanbanElements,
    )..where((e) => e.id.equals(id))).write(
      KanbanElementsCompanion(
        screenPinned: Value(pinned),
        x: x != null ? Value(x) : const Value.absent(),
        y: y != null ? Value(y) : const Value.absent(),
        pinnedScreenX: pinnedScreenX != null
            ? Value(pinnedScreenX)
            : const Value.absent(),
        pinnedScreenY: pinnedScreenY != null
            ? Value(pinnedScreenY)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Rewrites just the pinned on-screen position - the write a drag
  /// gesture on an already-pinned element commits (dragging a pinned
  /// element repositions its fixed screen anchor directly, never its
  /// board x/y, which stay untouched/stale until it's unpinned).
  Future<void> updatePinnedScreenPosition(
    String id, {
    required double x,
    required double y,
  }) {
    return (_db.update(
      _db.kanbanElements,
    )..where((e) => e.id.equals(id))).write(
      KanbanElementsCompanion(
        pinnedScreenX: Value(x),
        pinnedScreenY: Value(y),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteKanbanElement(String id) {
    return _db.transaction(() async {
      final columnIds =
          await (_db.selectOnly(_db.kanbanColumns)
                ..addColumns([_db.kanbanColumns.id])
                ..where(_db.kanbanColumns.kanbanElementId.equals(id)))
              .map((row) => row.read(_db.kanbanColumns.id)!)
              .get();

      if (columnIds.isNotEmpty) {
        final taskIds =
            await (_db.selectOnly(_db.kanbanTasks)
                  ..addColumns([_db.kanbanTasks.id])
                  ..where(_db.kanbanTasks.columnId.isIn(columnIds)))
                .map((row) => row.read(_db.kanbanTasks.id)!)
                .get();
        if (taskIds.isNotEmpty) {
          await (_db.delete(
            _db.kanbanTaskLinks,
          )..where((l) => l.taskId.isIn(taskIds))).go();
          await (_db.delete(
            _db.kanbanTasks,
          )..where((t) => t.id.isIn(taskIds))).go();
        }
        await (_db.delete(
          _db.kanbanColumns,
        )..where((c) => c.id.isIn(columnIds))).go();
      }

      await (_db.delete(
        _db.kanbanElements,
      )..where((e) => e.id.equals(id))).go();
    });
  }
}
