import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../local/database.dart';
import '../models/clip.dart';

const _uuid = Uuid();

/// Local read/write API for clips - every mutation writes straight to Drift.
class ClipsRepository {
  final AppDatabase _db;

  ClipsRepository(this._db);

  Stream<List<BoardClip>> watchActiveClips(String boardId) {
    final query = _db.select(_db.clips)
      ..where((c) => c.boardId.equals(boardId) & c.isBinned.equals(false))
      ..orderBy([(c) => OrderingTerm.asc(c.zIndex)]);
    return query.watch().map((rows) => rows.map(BoardClip.fromRow).toList());
  }

  Stream<List<BoardClip>> watchBinnedClips(String boardId) {
    final query = _db.select(_db.clips)
      ..where((c) => c.boardId.equals(boardId) & c.isBinned.equals(true))
      ..orderBy([(c) => OrderingTerm.desc(c.binnedAt)]);
    return query.watch().map((rows) => rows.map(BoardClip.fromRow).toList());
  }

  Future<int> _nextZIndex(String boardId) async {
    final query = _db.selectOnly(_db.clips)
      ..addColumns([_db.clips.zIndex.max()])
      ..where(_db.clips.boardId.equals(boardId));
    final row = await query.getSingleOrNull();
    final maxZ = row?.read(_db.clips.zIndex.max());
    return (maxZ ?? 0) + 1;
  }

  /// Adds an image clip pointing at an already-imported local file.
  Future<BoardClip> addImageClip({
    required String id,
    required String boardId,
    required String localFilePath,
    required double x,
    required double y,
    double width = kDefaultClipWidth,
    double height = kDefaultClipHeight,
    double rotation = 0,
    double? imageAspectRatio,
  }) async {
    final zIndex = await _nextZIndex(boardId);
    final row = await _insertClip(
      ClipsCompanion.insert(
        id: id,
        boardId: boardId,
        type: 'image',
        x: Value(x),
        y: Value(y),
        width: Value(width),
        height: Value(height),
        rotation: Value(rotation),
        zIndex: Value(zIndex),
        localFilePath: Value(localFilePath),
        imageAspectRatio: Value(imageAspectRatio),
      ),
    );
    return row;
  }

  Future<BoardClip> addTextNote({
    required String id,
    required String boardId,
    required String textContent,
    required double x,
    required double y,
    double width = kDefaultTextNoteWidth,
    double height = kDefaultTextNoteHeight,
  }) async {
    final zIndex = await _nextZIndex(boardId);
    return _insertClip(
      ClipsCompanion.insert(
        id: id,
        boardId: boardId,
        type: 'text',
        x: Value(x),
        y: Value(y),
        width: Value(width),
        height: Value(height),
        zIndex: Value(zIndex),
        textContent: Value(textContent),
      ),
    );
  }

  Future<BoardClip> _insertClip(ClipsCompanion companion) async {
    await _db.into(_db.clips).insert(companion);
    final row = await (_db.select(
      _db.clips,
    )..where((c) => c.id.equals(companion.id.value))).getSingle();
    return BoardClip.fromRow(row);
  }

  Future<void> updateTransform(
    String id, {
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    double? panX,
    double? panY,
    double? zoom,
  }) {
    return (_db.update(_db.clips)..where((c) => c.id.equals(id))).write(
      ClipsCompanion(
        x: x != null ? Value(x) : const Value.absent(),
        y: y != null ? Value(y) : const Value.absent(),
        width: width != null ? Value(width) : const Value.absent(),
        height: height != null ? Value(height) : const Value.absent(),
        rotation: rotation != null ? Value(rotation) : const Value.absent(),
        opacity: opacity != null ? Value(opacity) : const Value.absent(),
        imagePanX: panX != null ? Value(panX) : const Value.absent(),
        imagePanY: panY != null ? Value(panY) : const Value.absent(),
        imageZoom: zoom != null ? Value(zoom) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateTextContent(String id, String textContent) {
    return (_db.update(_db.clips)..where((c) => c.id.equals(id))).write(
      ClipsCompanion(
        textContent: Value(textContent),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Sets a text note's custom background color, or clears it back to the
  /// app default when [colorHex] is null.
  Future<void> updateBackgroundColor(String id, String? colorHex) {
    return (_db.update(_db.clips)..where((c) => c.id.equals(id))).write(
      ClipsCompanion(
        backgroundColorHex: Value(colorHex),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Sets or clears which frame this clip is nested inside - called
  /// whenever a clip drag ends and its new center point has entered or
  /// left a frame's bounds (Miro's frame-containment behavior).
  Future<void> setFrameId(String id, String? frameId) {
    return (_db.update(_db.clips)..where((c) => c.id.equals(id))).write(
      ClipsCompanion(frameId: Value(frameId), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> bringToFront(String id, String boardId) async {
    final zIndex = await _nextZIndex(boardId);
    await (_db.update(_db.clips)..where((c) => c.id.equals(id))).write(
      ClipsCompanion(zIndex: Value(zIndex), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> sendToBack(String id, String boardId) async {
    final query = _db.selectOnly(_db.clips)
      ..addColumns([_db.clips.zIndex.min()])
      ..where(
        _db.clips.boardId.equals(boardId) & _db.clips.isBinned.equals(false),
      );
    final row = await query.getSingleOrNull();
    final minZ = row?.read(_db.clips.zIndex.min()) ?? 0;
    await (_db.update(_db.clips)..where((c) => c.id.equals(id))).write(
      ClipsCompanion(zIndex: Value(minZ - 1), updatedAt: Value(DateTime.now())),
    );
  }

  Future<List<ClipRow>> _orderedActiveRows(String boardId) {
    final query = _db.select(_db.clips)
      ..where((c) => c.boardId.equals(boardId) & c.isBinned.equals(false))
      ..orderBy([(c) => OrderingTerm.asc(c.zIndex)]);
    return query.get();
  }

  Future<void> _swapZIndex(ClipRow a, ClipRow b) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.clips)..where((c) => c.id.equals(a.id))).write(
        ClipsCompanion(zIndex: Value(b.zIndex), updatedAt: Value(now)),
      );
      await (_db.update(_db.clips)..where((c) => c.id.equals(b.id))).write(
        ClipsCompanion(zIndex: Value(a.zIndex), updatedAt: Value(now)),
      );
    });
  }

  /// Swaps z-order with the clip immediately behind this one, if any.
  Future<void> sendBackward(String id, String boardId) async {
    final rows = await _orderedActiveRows(boardId);
    final index = rows.indexWhere((r) => r.id == id);
    if (index <= 0) return;
    await _swapZIndex(rows[index], rows[index - 1]);
  }

  /// Swaps z-order with the clip immediately in front of this one, if any.
  Future<void> bringForward(String id, String boardId) async {
    final rows = await _orderedActiveRows(boardId);
    final index = rows.indexWhere((r) => r.id == id);
    if (index == -1 || index >= rows.length - 1) return;
    await _swapZIndex(rows[index], rows[index + 1]);
  }

  Future<void> binClip(String id) {
    return (_db.update(_db.clips)..where((c) => c.id.equals(id))).write(
      ClipsCompanion(
        isBinned: const Value(true),
        binnedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restoreClip(String id) {
    return (_db.update(_db.clips)..where((c) => c.id.equals(id))).write(
      ClipsCompanion(
        isBinned: const Value(false),
        binnedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteForever(String id) {
    return (_db.delete(_db.clips)..where((c) => c.id.equals(id))).go();
  }

  Future<void> emptyBin(String boardId) {
    return (_db.delete(
      _db.clips,
    )..where((c) => c.boardId.equals(boardId) & c.isBinned.equals(true))).go();
  }

  /// Assigns a fresh group id to every clip in [ids], so clicking any one of
  /// them selects (and then drags) the whole set.
  Future<void> groupClips(List<String> ids) async {
    final groupId = _uuid.v4();
    await _db.transaction(() async {
      for (final id in ids) {
        await (_db.update(_db.clips)..where((c) => c.id.equals(id))).write(
          ClipsCompanion(groupId: Value(groupId), updatedAt: Value(DateTime.now())),
        );
      }
    });
  }

  /// Clears the group id from every clip currently sharing [groupId].
  Future<void> ungroupClips(String groupId) {
    return (_db.update(
      _db.clips,
    )..where((c) => c.groupId.equals(groupId))).write(
      ClipsCompanion(groupId: const Value(null), updatedAt: Value(DateTime.now())),
    );
  }
}
