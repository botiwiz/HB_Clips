import 'package:drift/drift.dart';

import '../local/database.dart';

/// Local read/write API for frames - same pattern as
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
    return _db
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
  }

  /// Inserts a full duplicate of [source] under [newId] (name, size,
  /// color, and position unless [x]/[y] override it) - [createFrame]
  /// can't be reused here since it has no way to carry over
  /// [backgroundColorHex] at creation time. Shared by Alt-drag-duplicate
  /// and internal copy/paste, same role [ClipsRepository.duplicateClip]
  /// plays for clips. Returns the inserted row (mirroring
  /// [ClipsRepository.duplicateClip]'s own return) so a caller that just
  /// duplicated a frame can immediately seed drag state from its real
  /// persisted values without a second read.
  Future<FrameRow> duplicateFrame(
    FrameRow source, {
    required String newId,
    double? x,
    double? y,
  }) async {
    await _db
        .into(_db.frames)
        .insert(
          FramesCompanion.insert(
            id: newId,
            boardId: source.boardId,
            name: Value(source.name),
            x: Value(x ?? source.x),
            y: Value(y ?? source.y),
            width: Value(source.width),
            height: Value(source.height),
            backgroundColorHex: Value(source.backgroundColorHex),
          ),
        );
    return (_db.select(
      _db.frames,
    )..where((f) => f.id.equals(newId))).getSingle();
  }

  Future<void> renameFrame(String id, String name) {
    return (_db.update(_db.frames)..where((f) => f.id.equals(id))).write(
      FramesCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> updateTransform(
    String id, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return (_db.update(_db.frames)..where((f) => f.id.equals(id))).write(
      FramesCompanion(
        x: x != null ? Value(x) : const Value.absent(),
        y: y != null ? Value(y) : const Value.absent(),
        width: width != null ? Value(width) : const Value.absent(),
        height: height != null ? Value(height) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateColor(String id, String? colorHex) {
    return (_db.update(_db.frames)..where((f) => f.id.equals(id))).write(
      FramesCompanion(
        backgroundColorHex: Value(colorHex),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteFrame(String id) {
    return _db.transaction(() async {
      // Deleting a frame unparents its children rather than deleting them -
      // they stay on the board exactly where they are, just no longer
      // grouped to (or moving with) anything.
      final children = await (_db.select(
        _db.clips,
      )..where((c) => c.frameId.equals(id))).get();
      for (final child in children) {
        await (_db.update(
          _db.clips,
        )..where((c) => c.id.equals(child.id))).write(
          ClipsCompanion(
            frameId: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      await (_db.delete(_db.frames)..where((f) => f.id.equals(id))).go();
    });
  }
}
