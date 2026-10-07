import 'package:drift/drift.dart';

import '../local/database.dart';

/// Thrown by [BoardsRepository.deleteBoard] when asked to delete the last
/// remaining board - there must always be at least one.
class LastBoardException implements Exception {
  const LastBoardException();

  @override
  String toString() => "Can't delete the only remaining board";
}

/// Local read/write API for boards - same pattern as
/// [ClipsRepository]/[StrokesRepository].
class BoardsRepository {
  final AppDatabase _db;

  BoardsRepository(this._db);

  Stream<List<BoardRow>> watchBoards() {
    final query = _db.select(_db.boards)
      ..orderBy([
        (b) => OrderingTerm.asc(b.sortOrder),
        (b) => OrderingTerm.asc(b.createdAt),
      ]);
    return query.watch();
  }

  Future<int> _nextSortOrder() async {
    final query = _db.selectOnly(_db.boards)
      ..addColumns([_db.boards.sortOrder.max()]);
    final row = await query.getSingleOrNull();
    final maxOrder = row?.read(_db.boards.sortOrder.max());
    return (maxOrder ?? 0) + 1;
  }

  Future<void> createBoard(String id, String name) async {
    final sortOrder = await _nextSortOrder();
    await _db
        .into(_db.boards)
        .insert(
          BoardsCompanion.insert(
            id: id,
            name: Value(name),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  /// Sets this board's "Manage boards" row-tint color, as `#RRGGBB`, or
  /// clears it back to the dialog's default background with `null`.
  Future<void> updateColor(String id, String? colorHex) {
    return (_db.update(_db.boards)..where((b) => b.id.equals(id))).write(
      BoardsCompanion(
        colorHex: Value(colorHex),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Persists a new display order for every board in [orderedIds] (as
  /// listed, lowest index sorts first) - drives "Manage boards"'
  /// drag-to-reorder, and everywhere else `watchBoards()` is read since
  /// they all share the same `sortOrder` column.
  Future<void> reorderBoards(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.boards)..where((b) => b.id.equals(orderedIds[i])))
          .write(BoardsCompanion(sortOrder: Value(i)));
    }
  }

  /// Persists this board's current pan/zoom camera, so switching back to
  /// it later resumes exactly here - see `BoardViewPersistenceController`,
  /// the only caller. Deliberately does NOT bump `updatedAt` - panning/
  /// zooming isn't "editing" the board's content, and `updatedAt` isn't
  /// read anywhere boards are listed (sortOrder/createdAt drive that), so
  /// there's no reason a camera move should look like a content edit.
  Future<void> updateViewState(
    String id, {
    required double panX,
    required double panY,
    required double scale,
  }) {
    return (_db.update(_db.boards)..where((b) => b.id.equals(id))).write(
      BoardsCompanion(
        viewPanX: Value(panX),
        viewPanY: Value(panY),
        viewScale: Value(scale),
      ),
    );
  }

  Future<void> renameBoard(String id, String name) {
    return (_db.update(_db.boards)..where((b) => b.id.equals(id))).write(
      BoardsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  /// Records which `.hbbackup` file this board was last opened from or
  /// saved to, so a later plain "Save" can write straight back to it
  /// with no dialog - see `board_backup_service.dart`. `path: null`
  /// clears the association (a board with no known file always behaves
  /// like "Save As" on its next Save).
  Future<void> updateBackupFilePath(String id, String? path) {
    return (_db.update(_db.boards)..where((b) => b.id.equals(id))).write(
      BoardsCompanion(
        backupFilePath: Value(path),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Deletes [id] along with every clip on it and their strokes/connectors.
  /// Throws [LastBoardException] instead of deleting the only remaining
  /// board.
  Future<void> deleteBoard(String id) async {
    final count = await _db
        .select(_db.boards)
        .get()
        .then((rows) => rows.length);
    if (count <= 1) throw const LastBoardException();

    await _db.transaction(() async {
      final clipIds = await (_db.select(
        _db.clips,
      )..where((c) => c.boardId.equals(id))).map((row) => row.id).get();
      for (final clipId in clipIds) {
        await (_db.delete(
          _db.strokes,
        )..where((s) => s.clipId.equals(clipId))).go();
      }
      await (_db.delete(
        _db.strokes,
      )..where((s) => s.boardId.equals(id) & s.clipId.isNull())).go();
      for (final clipId in clipIds) {
        await (_db.delete(_db.connectors)..where(
              (c) => c.fromClipId.equals(clipId) | c.toClipId.equals(clipId),
            ))
            .go();
      }
      await (_db.delete(_db.clips)..where((c) => c.boardId.equals(id))).go();
      await (_db.delete(_db.frames)..where((f) => f.boardId.equals(id))).go();
      await (_db.delete(_db.boards)..where((b) => b.id.equals(id))).go();
    });
  }
}
