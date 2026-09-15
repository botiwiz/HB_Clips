import 'package:drift/drift.dart';

import '../local/database.dart';
import '../sync/outbox.dart';

/// Local-first read/write API for frames - same pattern as
/// [BoardsRepository]/[ClipsRepository]/[StrokesRepository].
class FramesRepository {
  final AppDatabase _db;

  FramesRepository(this._db);

  Stream<List<FrameRow>> watchFrames(String boardId) {
    final query = _db.select(_db.frames)
      ..where((f) => f.boardId.equals(boardId))
      ..orderBy([(f) => OrderingTerm.asc(f.createdAt)]);
    return query.watch();
  }

  Future<void> createFrame({
    required String id,
    required String boardId,
    required String name,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    return _db.transaction(() async {
      await _db
          .into(_db.frames)
          .insert(
            FramesCompanion.insert(
              id: id,
              boardId: boardId,
              name: Value(name),
              x: Value(x),
              y: Value(y),
              width: Value(width),
              height: Value(height),
            ),
          );
      await enqueueOutbox(
        _db,
        entityType: 'frame',
        entityId: id,
        operation: 'upsert',
      );
    });
  }

  Future<void> renameFrame(String id, String name) {
    return _db.transaction(() async {
      await (_db.update(_db.frames)..where((f) => f.id.equals(id))).write(
        FramesCompanion(
          name: Value(name),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ),
      );
      await enqueueOutbox(
        _db,
        entityType: 'frame',
        entityId: id,
        operation: 'upsert',
      );
    });
  }

  Future<void> updateTransform(
    String id, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.frames)..where((f) => f.id.equals(id))).write(
        FramesCompanion(
          x: x != null ? Value(x) : const Value.absent(),
          y: y != null ? Value(y) : const Value.absent(),
          width: width != null ? Value(width) : const Value.absent(),
          height: height != null ? Value(height) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ),
      );
      await enqueueOutbox(
        _db,
        entityType: 'frame',
        entityId: id,
        operation: 'upsert',
      );
    });
  }

  Future<void> deleteFrame(String id) {
    return _db.transaction(() async {
      await (_db.delete(_db.frames)..where((f) => f.id.equals(id))).go();
      await enqueueOutbox(
        _db,
        entityType: 'frame',
        entityId: id,
        operation: 'delete',
      );
    });
  }
}
