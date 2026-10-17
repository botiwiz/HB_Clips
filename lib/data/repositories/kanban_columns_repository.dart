import 'package:drift/drift.dart';

import '../local/database.dart';

/// Local read/write API for kanban columns (Trello-style lists). A column
/// only ever exists as a child of exactly one [KanbanElementRow] - there
/// is no spatial reparenting the way `Clips.frameId`/old `kanban_boards`
/// tagging worked, [kanbanElementId] is a plain, permanent foreign key.
class KanbanColumnsRepository {
  final AppDatabase _db;

  KanbanColumnsRepository(this._db);

  /// Watches every column belonging to any kanban element on [boardId],
  /// in one subscription (joined through `kanban_elements`) - "watch
  /// everything for the parent scope, consumers group/sort in-memory" is
  /// this codebase's established convention (see `watchFrames`/old
  /// `watchSwimlanes`), so grouping by `kanbanElementId` and ordering by
  /// `sortOrder` is left to the caller (`KanbanColumnGeometry`) rather
  /// than done here.
  Stream<List<KanbanColumnRow>> watchColumnsForBoard(String boardId) {
    final query = _db.select(_db.kanbanColumns).join([
      innerJoin(
        _db.kanbanElements,
        _db.kanbanElements.id.equalsExp(_db.kanbanColumns.kanbanElementId),
      ),
    ])..where(_db.kanbanElements.boardId.equals(boardId));
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_db.kanbanColumns)).toList(),
    );
  }

  /// `MAX(sortOrder) + 1.0` among [kanbanElementId]'s columns - appends a
  /// new column after every existing one (see the Kanban-rebuild plan's
  /// "ordering: fractional indexing" section).
  Future<double> _nextSortOrder(String kanbanElementId) async {
    final query = _db.selectOnly(_db.kanbanColumns)
      ..addColumns([_db.kanbanColumns.sortOrder.max()])
      ..where(_db.kanbanColumns.kanbanElementId.equals(kanbanElementId));
    final row = await query.getSingleOrNull();
    final maxOrder = row?.read(_db.kanbanColumns.sortOrder.max());
    return (maxOrder ?? 0) + 1.0;
  }

  /// Creates a column at the end (highest [KanbanColumnRow.sortOrder])
  /// unless [sortOrder] is given explicitly (used when seeding several
  /// columns at once, e.g. "Insert Kanban Board", so each one's order is
  /// assigned up front rather than depending on insertion order).
  Future<KanbanColumnRow> createColumn({
    required String id,
    required String kanbanElementId,
    required String name,
    double? sortOrder,
    String? colorHex,
  }) async {
    final order = sortOrder ?? await _nextSortOrder(kanbanElementId);
    await _db
        .into(_db.kanbanColumns)
        .insert(
          KanbanColumnsCompanion.insert(
            id: id,
            kanbanElementId: kanbanElementId,
            name: Value(name),
            sortOrder: Value(order),
            colorHex: Value(colorHex),
          ),
        );
    return (_db.select(
      _db.kanbanColumns,
    )..where((c) => c.id.equals(id))).getSingle();
  }

  Future<void> renameColumn(String id, String name) {
    return (_db.update(
      _db.kanbanColumns,
    )..where((c) => c.id.equals(id))).write(
      KanbanColumnsCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Sets (or clears, with `null`) a column's accent color - same plain
  /// setter shape as `FramesRepository.updateColor`.
  Future<void> updateColor(String id, String? colorHex) {
    return (_db.update(
      _db.kanbanColumns,
    )..where((c) => c.id.equals(id))).write(
      KanbanColumnsCompanion(
        colorHex: Value(colorHex),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Rewrites one column's left-to-right position - a column drag only
  /// ever touches this single row's value (see the fractional-indexing
  /// section of the Kanban-rebuild plan).
  Future<void> updateSortOrder(String id, double sortOrder) {
    return (_db.update(
      _db.kanbanColumns,
    )..where((c) => c.id.equals(id))).write(
      KanbanColumnsCompanion(
        sortOrder: Value(sortOrder),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Deletes a column, cascading to every task inside it (and those
  /// tasks' links) - a task never outlives the column that owns it.
  Future<void> deleteColumn(String id) {
    return _db.transaction(() async {
      final taskIds =
          await (_db.selectOnly(_db.kanbanTasks)
                ..addColumns([_db.kanbanTasks.id])
                ..where(_db.kanbanTasks.columnId.equals(id)))
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
      )..where((c) => c.id.equals(id))).go();
    });
  }
}
