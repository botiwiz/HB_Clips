import 'dart:io';

import 'package:drift/drift.dart';

import '../local/database.dart';
import '../models/clip.dart';
import '../models/stroke.dart';
import '../remote/boards_remote_source.dart';
import '../remote/clips_remote_source.dart';
import '../remote/storage_source.dart';
import '../remote/strokes_remote_source.dart';

/// Drains the local outbox (`SyncQueueEntries`) FIFO, pushing each pending
/// mutation to the remote backend. An image clip upload-then-metadata-
/// upsert is one retryable unit: both must succeed for that queue entry to
/// be removed. On failure, the entry's `attemptCount`/`lastError` are
/// recorded and every later entry for the *same* entity is skipped for
/// this pass (to preserve per-entity ordering) - entries for other
/// entities still drain normally. Pacing repeated `drainOnce()` calls
/// (retry backoff, periodic ticks) is the caller's job (`sync_engine.dart`).
class SyncQueueDrainer {
  final AppDatabase _db;

  /// Resolved lazily on each image upload rather than captured once at
  /// construction, so a drainer created early doesn't hold a stale id
  /// across a session change.
  final String Function() _currentUserId;
  final ClipsRemoteSource _clips;
  final StrokesRemoteSource _strokes;
  final BoardsRemoteSource _boards;
  final StorageSource _storage;

  SyncQueueDrainer(
    this._db,
    this._currentUserId,
    this._clips,
    this._strokes,
    this._boards,
    this._storage,
  );

  Future<void> drainOnce() async {
    final failedEntityKeys = <String>{};
    final entries = await (_db.select(_db.syncQueueEntries)
          ..orderBy([(e) => OrderingTerm.asc(e.id)]))
        .get();

    for (final entry in entries) {
      final key = '${entry.entityType}:${entry.entityId}';
      if (failedEntityKeys.contains(key)) continue;

      try {
        await _processEntry(entry);
        await (_db.delete(
          _db.syncQueueEntries,
        )..where((e) => e.id.equals(entry.id))).go();
      } catch (error) {
        failedEntityKeys.add(key);
        await (_db.update(_db.syncQueueEntries)..where((e) => e.id.equals(entry.id)))
            .write(
              SyncQueueEntriesCompanion(
                attemptCount: Value(entry.attemptCount + 1),
                lastError: Value(error.toString()),
              ),
            );
      }
    }
  }

  Future<void> _processEntry(SyncQueueEntry entry) async {
    if (entry.operation == 'delete') {
      switch (entry.entityType) {
        case 'clip':
          await _clips.delete(entry.entityId);
        case 'stroke':
          await _strokes.delete(entry.entityId);
        case 'board':
          await _boards.delete(entry.entityId);
      }
      return;
    }

    switch (entry.entityType) {
      case 'clip':
        await _pushClip(entry.entityId);
      case 'stroke':
        await _pushStroke(entry.entityId);
      case 'board':
        await _pushBoard(entry.entityId);
    }
  }

  Future<void> _pushClip(String id) async {
    final row = await (_db.select(
      _db.clips,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    // Deleted locally since this entry was enqueued - the matching
    // 'delete' entry (enqueued at delete time) handles the remote side;
    // nothing to push for this now-stale 'upsert'.
    if (row == null) return;

    var clip = BoardClip.fromRow(row);
    if (clip.type == ClipType.image &&
        clip.storagePath == null &&
        clip.localFilePath != null) {
      final storagePath = await _storage.uploadImage(
        userId: _currentUserId(),
        clipId: clip.id,
        localFile: File(clip.localFilePath!),
      );
      await (_db.update(_db.clips)..where((c) => c.id.equals(clip.id))).write(
        ClipsCompanion(storagePath: Value(storagePath)),
      );
      clip = clip.copyWith(storagePath: storagePath);
    }

    await _clips.upsert(clip);
    await (_db.update(_db.clips)..where((c) => c.id.equals(clip.id))).write(
      const ClipsCompanion(dirty: Value(false)),
    );
  }

  Future<void> _pushStroke(String id) async {
    final row = await (_db.select(
      _db.strokes,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final stroke = Stroke.fromRow(row);
    await _strokes.upsert(stroke);
    await (_db.update(_db.strokes)..where((s) => s.id.equals(stroke.id))).write(
      const StrokesCompanion(dirty: Value(false)),
    );
  }

  Future<void> _pushBoard(String id) async {
    final row = await (_db.select(
      _db.boards,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    await _boards.upsert(row);
    await (_db.update(_db.boards)..where((b) => b.id.equals(row.id))).write(
      const BoardsCompanion(dirty: Value(false)),
    );
  }
}
