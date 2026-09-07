import 'package:drift/drift.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/database.dart';
import '../models/stroke.dart';
import '../remote/storage_source.dart';

/// Whether an incoming remote row should overwrite the local one.
///
/// A `dirty` local row always wins - it has an unpushed local edit still
/// waiting in the outbox, and applying the remote version now would lose
/// that edit (the drainer will push it and clear `dirty` in its own time,
/// at which point future remote echoes apply normally again). Otherwise
/// it's last-write-wins by `updated_at`: a `null` [localUpdatedAt] means
/// there's no local row at all yet, so the remote row is always applied.
bool shouldApplyRemote({
  required DateTime? localUpdatedAt,
  required bool localDirty,
  required DateTime remoteUpdatedAt,
}) {
  if (localDirty) return false;
  if (localUpdatedAt == null) return true;
  return remoteUpdatedAt.isAfter(localUpdatedAt);
}

/// Subscribes to Postgres changes on `boards`/`clips`/`strokes`, filtered
/// to the signed-in user, and applies them to the local Drift database -
/// the live, cross-device half of sync (the outbox/drainer is the push
/// half). [shouldApplyRemote] gates every write so a local pending edit is
/// never silently overwritten by another device's echo.
class RealtimeListener {
  final AppDatabase _db;
  final SupabaseClient _client;
  final StorageSource _storage;

  RealtimeChannel? _channel;

  RealtimeListener(this._db, this._client, this._storage);

  void start() {
    if (_channel != null) return; // already started
    final userId = _client.auth.currentUser!.id;
    final userFilter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: userId,
    );

    _channel = _client
        .channel('hb_clips_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'boards',
          filter: userFilter,
          callback: (payload) => _handleBoardChange(payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clips',
          filter: userFilter,
          callback: (payload) => _handleClipChange(payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'strokes',
          filter: userFilter,
          callback: (payload) => _handleStrokeChange(payload),
        )
        .subscribe();
  }

  Future<void> stop() async {
    final channel = _channel;
    if (channel == null) return;
    _channel = null;
    await _client.removeChannel(channel);
  }

  Future<void> _handleBoardChange(PostgresChangePayload payload) async {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = payload.oldRecord['id'] as String?;
      if (id == null) return;
      final local = await (_db.select(
        _db.boards,
      )..where((b) => b.id.equals(id))).getSingleOrNull();
      if (local == null || local.dirty) return;
      await (_db.delete(_db.boards)..where((b) => b.id.equals(id))).go();
      return;
    }

    final r = payload.newRecord;
    final id = r['id'] as String;
    final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
    final local = await (_db.select(
      _db.boards,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    if (!shouldApplyRemote(
      localUpdatedAt: local?.updatedAt,
      localDirty: local?.dirty ?? false,
      remoteUpdatedAt: remoteUpdatedAt,
    )) {
      return;
    }

    await _db
        .into(_db.boards)
        .insertOnConflictUpdate(
          BoardsCompanion.insert(
            id: id,
            name: Value(r['name'] as String),
            createdAt: Value(DateTime.parse(r['created_at'] as String)),
            updatedAt: Value(remoteUpdatedAt),
            dirty: const Value(false),
          ),
        );
  }

  Future<void> _handleClipChange(PostgresChangePayload payload) async {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = payload.oldRecord['id'] as String?;
      if (id == null) return;
      final local = await (_db.select(
        _db.clips,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (local == null || local.dirty) return;
      await (_db.delete(_db.clips)..where((c) => c.id.equals(id))).go();
      return;
    }

    final r = payload.newRecord;
    final id = r['id'] as String;
    final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
    final local = await (_db.select(
      _db.clips,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (!shouldApplyRemote(
      localUpdatedAt: local?.updatedAt,
      localDirty: local?.dirty ?? false,
      remoteUpdatedAt: remoteUpdatedAt,
    )) {
      return;
    }

    final storagePath = r['storage_path'] as String?;
    await _db
        .into(_db.clips)
        .insertOnConflictUpdate(
          ClipsCompanion.insert(
            id: id,
            boardId: r['board_id'] as String,
            type: r['type'] as String,
            x: Value((r['x'] as num).toDouble()),
            y: Value((r['y'] as num).toDouble()),
            width: Value((r['width'] as num).toDouble()),
            height: Value((r['height'] as num).toDouble()),
            rotation: Value((r['rotation'] as num).toDouble()),
            zIndex: Value(r['z_index'] as int),
            opacity: Value((r['opacity'] as num).toDouble()),
            textContent: Value(r['text_content'] as String?),
            backgroundColorHex: Value(r['background_color_hex'] as String?),
            groupId: Value(r['group_id'] as String?),
            storagePath: Value(storagePath),
            // localFilePath is deliberately not set here - left absent so
            // an existing row's already-cached download isn't clobbered;
            // a brand-new row from another device starts with none, and
            // gets downloaded just below if needed.
            isBinned: Value(r['is_binned'] as bool),
            binnedAt: Value(
              r['binned_at'] != null
                  ? DateTime.parse(r['binned_at'] as String)
                  : null,
            ),
            createdAt: Value(DateTime.parse(r['created_at'] as String)),
            updatedAt: Value(remoteUpdatedAt),
            dirty: const Value(false),
          ),
        );

    if (r['type'] == 'image' && storagePath != null) {
      final row = await (_db.select(
        _db.clips,
      )..where((c) => c.id.equals(id))).getSingle();
      if (row.localFilePath == null) {
        final localPath = await _storage.downloadImage(
          clipId: id,
          storagePath: storagePath,
        );
        await (_db.update(_db.clips)..where((c) => c.id.equals(id))).write(
          ClipsCompanion(localFilePath: Value(localPath)),
        );
      }
    }
  }

  Future<void> _handleStrokeChange(PostgresChangePayload payload) async {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = payload.oldRecord['id'] as String?;
      if (id == null) return;
      final local = await (_db.select(
        _db.strokes,
      )..where((s) => s.id.equals(id))).getSingleOrNull();
      if (local == null || local.dirty) return;
      await (_db.delete(_db.strokes)..where((s) => s.id.equals(id))).go();
      return;
    }

    final r = payload.newRecord;
    final id = r['id'] as String;
    final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
    final local = await (_db.select(
      _db.strokes,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (!shouldApplyRemote(
      localUpdatedAt: local?.updatedAt,
      localDirty: local?.dirty ?? false,
      remoteUpdatedAt: remoteUpdatedAt,
    )) {
      return;
    }

    final rawPoints = (r['points'] as List<dynamic>)
        .map(
          (p) => Offset(
            ((p as List<dynamic>)[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          ),
        )
        .toList();

    await _db
        .into(_db.strokes)
        .insertOnConflictUpdate(
          StrokesCompanion.insert(
            id: id,
            boardId: r['board_id'] as String,
            clipId: Value(r['clip_id'] as String?),
            color: Value(r['color'] as String),
            strokeWidth: Value((r['stroke_width'] as num).toDouble()),
            pointsJson: Stroke.encodePoints(rawPoints),
            dashed: Value(r['dashed'] as bool),
            arrowEnd: Value(r['arrow_end'] as bool),
            createdAt: Value(DateTime.parse(r['created_at'] as String)),
            updatedAt: Value(remoteUpdatedAt),
            dirty: const Value(false),
          ),
        );
  }
}
