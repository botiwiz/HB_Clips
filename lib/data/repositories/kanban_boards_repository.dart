import 'package:drift/drift.dart';

import '../local/database.dart';

/// Local read/write API for kanban-board "insert as one unit" rows - see
/// `KanbanBoards`' own doc comment for why `x`/`y`/`width`/`height` are a
/// creation-time snapshot only, never read back as authoritative geometry.
class KanbanBoardsRepository {
  final AppDatabase _db;

  KanbanBoardsRepository(this._db);

  Stream<List<KanbanBoardRow>> watchKanbanBoards(String boardId) {
    final query = _db.select(_db.kanbanBoards)
      ..where((k) => k.boardId.equals(boardId));
    return query.watch();
  }

  Future<void> createKanbanBoard({
    required String id,
    required String boardId,
    required String name,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    return _db
        .into(_db.kanbanBoards)
        .insert(
          KanbanBoardsCompanion.insert(
            id: id,
            boardId: boardId,
            name: Value(name),
            x: Value(x),
            y: Value(y),
            width: Value(width),
            height: Value(height),
          ),
        );
  }

  /// Deletes the kanban-board row, every Swimlane tagged with it
  /// (cascade-DELETE, not cascade-unparent - see `Swimlanes
  /// .kanbanBoardId`'s NOT-NULL doc comment), and clears `kanbanBoardId`
  /// on every Frame tagged with it (cascade-UNPARENT, same convention
  /// `FramesRepository.deleteFrame` already uses for clips - the Frames
  /// themselves survive as plain, untagged Frames).
  Future<void> deleteKanbanBoard(String id) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.swimlanes,
      )..where((s) => s.kanbanBoardId.equals(id))).go();
      await (_db.update(
        _db.frames,
      )..where((f) => f.kanbanBoardId.equals(id))).write(
        const FramesCompanion(kanbanBoardId: Value(null)),
      );
      await (_db.delete(_db.kanbanBoards)..where((k) => k.id.equals(id))).go();
    });
  }
}
