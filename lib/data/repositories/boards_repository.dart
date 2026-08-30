import 'package:drift/drift.dart';

import '../local/database.dart';

/// Thrown by [BoardsRepository.deleteBoard] when asked to delete the last
/// remaining board - there must always be at least one.
class LastBoardException implements Exception {
  const LastBoardException();

  @override
  String toString() => "Can't delete the only remaining board";
}

/// Local-first read/write API for boards - same pattern as
/// [ClipsRepository]/[StrokesRepository].
class BoardsRepository {
  final AppDatabase _db;

  BoardsRepository(this._db);

  Stream<List<BoardRow>> watchBoards() {
    final query = _db.select(_db.boards)
      ..orderBy([(b) => OrderingTerm.asc(b.createdAt)]);
    return query.watch();
  }

  Future<void> createBoard(String id, String name) {
    return _db.into(_db.boards).insert(
      BoardsCompanion.insert(id: id, name: Value(name)),
    );
  }

  Future<void> renameBoard(String id, String name) {
    return (_db.update(_db.boards)..where((b) => b.id.equals(id))).write(
      BoardsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  /// Deletes [id] along with every clip on it and their strokes. Throws
  /// [LastBoardException] instead of deleting the only remaining board.
  Future<void> deleteBoard(String id) async {
    final count = await _db.select(_db.boards).get().then((rows) => rows.length);
    if (count <= 1) throw const LastBoardException();

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
    await (_db.delete(_db.clips)..where((c) => c.boardId.equals(id))).go();
    await (_db.delete(_db.boards)..where((b) => b.id.equals(id))).go();
  }
}
