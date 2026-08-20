import 'package:drift/drift.dart';
import 'package:flutter/rendering.dart';

import '../local/database.dart';
import '../models/stroke.dart';

/// Local-first read/write API for annotation strokes - same pattern as
/// [ClipsRepository]: every mutation writes straight to Drift, no network
/// yet (Phase 6 adds the sync outbox on top of these same methods).
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
  }) {
    return _db.into(_db.strokes).insert(
      StrokesCompanion.insert(
        id: id,
        boardId: boardId,
        clipId: Value(clipId),
        color: Value(colorHex),
        strokeWidth: Value(strokeWidth),
        pointsJson: Stroke.encodePoints(points),
      ),
    );
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
    await (_db.delete(_db.strokes)..where((s) => s.id.equals(row.id))).go();
  }

  /// Deletes every stroke attached to [clipId]. Callers are responsible
  /// for invoking this when a clip is permanently deleted (Phase 4) - not
  /// wired up yet since "Delete Forever" has no UI until then.
  Future<void> deleteStrokesForClip(String clipId) {
    return (_db.delete(_db.strokes)..where((s) => s.clipId.equals(clipId))).go();
  }
}
