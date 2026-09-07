import 'package:drift/drift.dart';
import 'package:flutter/rendering.dart';

import '../local/database.dart';
import '../models/stroke.dart';
import '../sync/outbox.dart';

/// Local-first read/write API for annotation strokes - same pattern as
/// [ClipsRepository]: every mutation writes straight to Drift first, then
/// enqueues a matching outbox entry in the same transaction.
class StrokesRepository {
  final AppDatabase _db;

  StrokesRepository(this._db);

  Stream<List<Stroke>> watchStrokes(String boardId) {
    final query = _db.select(_db.strokes)
      ..where((s) => s.boardId.equals(boardId))
      ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]);
    return query.watch().map((rows) => rows.map(Stroke.fromRow).toList());
  }

  Future<void> addStroke({
    required String id,
    required String boardId,
    String? clipId,
    required String colorHex,
    required double strokeWidth,
    required List<Offset> points,
    bool dashed = false,
    bool arrowEnd = false,
  }) {
    return _db.transaction(() async {
      await _db.into(_db.strokes).insert(
        StrokesCompanion.insert(
          id: id,
          boardId: boardId,
          clipId: Value(clipId),
          color: Value(colorHex),
          strokeWidth: Value(strokeWidth),
          pointsJson: Stroke.encodePoints(points),
          dashed: Value(dashed),
          arrowEnd: Value(arrowEnd),
        ),
      );
      await enqueueOutbox(_db, entityType: 'stroke', entityId: id, operation: 'upsert');
    });
  }

  /// Removes the single most recently drawn stroke on the board, if any -
  /// the "undo" affordance for the draw tool. Not a full undo stack.
  Future<void> deleteMostRecentStroke(String boardId) async {
    final query = _db.select(_db.strokes)
      ..where((s) => s.boardId.equals(boardId))
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) return;
    await _db.transaction(() async {
      await (_db.delete(_db.strokes)..where((s) => s.id.equals(row.id))).go();
      await enqueueOutbox(_db, entityType: 'stroke', entityId: row.id, operation: 'delete');
    });
  }

  /// Deletes every stroke attached to [clipId]. Callers are responsible
  /// for invoking this when a clip is permanently deleted.
  Future<void> deleteStrokesForClip(String clipId) {
    return _db.transaction(() async {
      final ids = await (_db.selectOnly(_db.strokes)
            ..addColumns([_db.strokes.id])
            ..where(_db.strokes.clipId.equals(clipId)))
          .map((row) => row.read(_db.strokes.id)!)
          .get();
      await (_db.delete(_db.strokes)..where((s) => s.clipId.equals(clipId))).go();
      for (final id in ids) {
        await enqueueOutbox(_db, entityType: 'stroke', entityId: id, operation: 'delete');
      }
    });
  }

  /// Deletes a single stroke by id - the eraser tool's primitive (erasing
  /// removes whichever whole strokes the pointer touches, not partial
  /// segments).
  Future<void> deleteStroke(String id) {
    return _db.transaction(() async {
      await (_db.delete(_db.strokes)..where((s) => s.id.equals(id))).go();
      await enqueueOutbox(_db, entityType: 'stroke', entityId: id, operation: 'delete');
    });
  }
}
