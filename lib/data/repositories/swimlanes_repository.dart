import 'package:drift/drift.dart';

import '../local/database.dart';

/// Local read/write API for kanban swimlanes (horizontal row bands within
/// one specific kanban board's column extent) - see `Swimlanes`' own doc
/// comment for why a lane has no stored x/width.
class SwimlanesRepository {
  final AppDatabase _db;

  SwimlanesRepository(this._db);

  /// All swimlanes across every kanban board on [boardId] - same "watch
  /// everything for the board, filter by parent in-memory" convention
  /// `watchFrames`/`watchActiveClips` already use (no dedicated
  /// per-kanban-board query method, matching this codebase's established
  /// "no cached-children query" rule).
  Stream<List<SwimlaneRow>> watchSwimlanes(String boardId) {
    final query = _db.select(_db.swimlanes).join([
      innerJoin(
        _db.kanbanBoards,
        _db.kanbanBoards.id.equalsExp(_db.swimlanes.kanbanBoardId),
      ),
    ])..where(_db.kanbanBoards.boardId.equals(boardId));
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(_db.swimlanes)).toList(),
    );
  }

  Future<void> createSwimlane({
    required String id,
    required String kanbanBoardId,
    required String name,
    required double y,
    required double height,
    required int sortOrder,
    String? colorHex,
  }) {
    return _db
        .into(_db.swimlanes)
        .insert(
          SwimlanesCompanion.insert(
            id: id,
            kanbanBoardId: kanbanBoardId,
            name: Value(name),
            y: Value(y),
            height: Value(height),
            sortOrder: Value(sortOrder),
            colorHex: Value(colorHex),
          ),
        );
  }

  Future<void> renameSwimlane(String id, String name) {
    return (_db.update(_db.swimlanes)..where((s) => s.id.equals(id))).write(
      SwimlanesCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> updateTransform(String id, {double? y, double? height}) {
    return (_db.update(_db.swimlanes)..where((s) => s.id.equals(id))).write(
      SwimlanesCompanion(
        y: y != null ? Value(y) : const Value.absent(),
        height: height != null ? Value(height) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteSwimlane(String id) {
    return _db.transaction(() async {
      await (_db.update(
        _db.clips,
      )..where((c) => c.swimlaneId.equals(id))).write(
        const ClipsCompanion(swimlaneId: Value(null)),
      );
      await (_db.delete(_db.swimlanes)..where((s) => s.id.equals(id))).go();
    });
  }
}
